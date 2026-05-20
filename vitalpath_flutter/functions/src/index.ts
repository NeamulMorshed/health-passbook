import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {Timestamp} from "firebase-admin/firestore";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Maps Firestore notification type to the Flutter in-app channel key, which
// the Flutter app reads in _routeForChannel() to decide where to navigate.
function channelForType(type: string | undefined): string {
  switch (type) {
    case "appointment": return "appointment_reminders";
    case "medicineReminder": return "medicine_reminders";
    default: return "general";
  }
}

/**
 * Triggered whenever a new notification document is written to
 * patients/{patientId}/notifications/{notifId}.
 *
 * Reads the patient's FCM device token from users/{patientId} and sends
 * a real push notification so the device is woken up even when the app
 * is in the background or terminated.
 */
export const sendPushOnNotification = functions.firestore
  .document("patients/{patientId}/notifications/{notifId}")
  .onCreate(async (snap, context) => {
    const {patientId} = context.params;
    const data = snap.data();

    if (!data) return;

    // Look up the user's device token.
    const userDoc = await db.collection("users").doc(patientId).get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;

    if (!fcmToken) {
      // Token not yet saved (user hasn't opened the app since the fix).
      return;
    }

    const channel = channelForType(data.type as string | undefined);

    try {
      await messaging.send({
        token: fcmToken,
        notification: {
          title: (data.title as string) ?? "Omra",
          body: (data.body as string) ?? "",
        },
        data: {
          channel,
          notifId: snap.id,
          patientId,
        },
        android: {
          priority: "high",
          notification: {
            channelId: channel,
            sound: "default",
            priority: "max",
          },
        },
        apns: {
          payload: {aps: {sound: "default", badge: 1}},
        },
      });

      // Mark the Firestore document so we don't resend if the function retries.
      await snap.ref.update({pushSent: true});
    } catch (err) {
      functions.logger.error("FCM send failed", {patientId, notifId: snap.id, err});
    }
  });

/**
 * Runs every 30 minutes. For each patient's active medicines, checks whether
 * a scheduled reminder time fell in the past 30-minute window and the dose
 * was not logged. If so, writes a notification document for the patient
 * (which triggers sendPushOnNotification) and sends a direct push to any
 * connected caregivers who have missedDose notifications enabled.
 */
export const checkMissedDoses = functions.pubsub
  .schedule("every 30 minutes")
  .onRun(async () => {
    const now = new Date();
    const windowStart = new Date(now.getTime() - 30 * 60 * 1000);

    // Load all patient medicine subcollections.
    const patientsSnap = await db.collection("patients").get();
    const tasks: Promise<void>[] = [];

    for (const patientDoc of patientsSnap.docs) {
      tasks.push(_checkPatientMissedDoses(patientDoc.id, now, windowStart));
    }
    await Promise.allSettled(tasks);
  });

async function _checkPatientMissedDoses(
  patientId: string,
  now: Date,
  windowStart: Date
): Promise<void> {
  const medsSnap = await db
    .collection("patients")
    .doc(patientId)
    .collection("medicines")
    .where("isActive", "==", true)
    .get();

  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayStr = today.toISOString().split("T")[0]; // "YYYY-MM-DD"

  for (const medDoc of medsSnap.docs) {
    const med = medDoc.data();
    const reminderTimes: string[] = med.reminderTimes ?? [];
    if (reminderTimes.length === 0) continue;

    const loggedDoses: Timestamp[] = med.loggedDoses ?? [];
    const dosedToday = loggedDoses.some((ts) => {
      const d = ts.toDate();
      return d.toISOString().split("T")[0] === todayStr;
    });
    if (dosedToday) continue;

    // Check if any reminder time fell in the past 30-minute window.
    const hasMissed = reminderTimes.some((t) => {
      const [hStr, mStr] = t.split(":");
      const slotTime = new Date(today);
      slotTime.setHours(parseInt(hStr, 10), parseInt(mStr ?? "0", 10), 0, 0);
      return slotTime >= windowStart && slotTime <= now;
    });

    if (!hasMissed) continue;

    // Write a notification for the patient.
    await db
      .collection("patients")
      .doc(patientId)
      .collection("notifications")
      .add({
        type: "missedDose",
        title: "Missed dose",
        body: `${med.name ?? "A medicine"} hasn't been taken yet.`,
        createdAt: Timestamp.fromDate(now),
        read: false,
        pushSent: false,
      });

    // Also notify connected caregivers with missedDose setting enabled.
    const connSnap = await db
      .collection("caregiver_connections")
      .where("patientId", "==", patientId)
      .where("status", "==", "connected")
      .get();

    for (const connDoc of connSnap.docs) {
      const conn = connDoc.data();
      if (!conn.notifSettings?.missedDose) continue;

      const caregiverDoc = await db.collection("users").doc(conn.caregiverId).get();
      const fcmToken = caregiverDoc.data()?.fcmToken as string | undefined;
      if (!fcmToken) continue;

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: `${conn.patientName ?? "Your family member"} missed a dose`,
            body: `${med.name ?? "A medicine"} hasn't been taken yet.`,
          },
          data: {
            channel: "medicine_reminders",
            patientId,
          },
          android: {
            priority: "high",
            notification: {channelId: "medicine_reminders", priority: "high"},
          },
          apns: {payload: {aps: {sound: "default"}}},
        });
      } catch (err) {
        functions.logger.warn("Caregiver FCM send failed", {caregiverId: conn.caregiverId, err});
      }
    }
  }
}
