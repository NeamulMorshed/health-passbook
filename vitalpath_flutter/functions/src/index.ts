import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
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
 * Runs every 30 minutes. Uses a collectionGroup query on medicines (S-07) so
 * only patients who have at least one active medicine are touched — no O(n)
 * full-patients scan. Patients with zero active medicines are skipped entirely.
 */
export const checkMissedDoses = onSchedule("every 30 minutes", async () => {
    const now = new Date();
    const windowStart = new Date(now.getTime() - 30 * 60 * 1000);

    // S-07: collectionGroup query replaces loading all patients.
    const medsSnap = await db
      .collectionGroup("medicines")
      .where("isActive", "==", true)
      .get();

    // Group medicine docs by patient ID extracted from the subcollection path.
    const byPatient = new Map<string, admin.firestore.QueryDocumentSnapshot[]>();
    for (const medDoc of medsSnap.docs) {
      const patientId = medDoc.ref.parent.parent?.id;
      if (!patientId) continue;
      const arr = byPatient.get(patientId) ?? [];
      arr.push(medDoc);
      byPatient.set(patientId, arr);
    }

    const tasks: Promise<void>[] = [];
    for (const [patientId, medDocs] of byPatient) {
      tasks.push(_checkPatientMissedDoses(patientId, medDocs, now, windowStart));
    }
    await Promise.allSettled(tasks);
  });

// ─── Appointment Reminders (ADR-015) ──────────────────────────────────────────
// Day-before fires when hoursUntil ∈ [23.5, 24.5).
// "Soon" fires when minutesUntil ∈ [0, 30) — 30-min poll reliably catches the
// 15-min mark. Future: read per-user appointmentReminderLeadMinutes from Firestore.
// Idempotency: appointments/{id}.reminders.{dayBeforeSentAt|soonSentAt} guards duplicates.
// Required composite index: appointments → (status ASC, scheduledAt ASC).

interface _ApptReminderPayload {
  apptId: string;
  patientId: string;
  doctorId: string;
  patientName?: string;
  patientTitle: string;
  patientBody: string;
  doctorTitle: string;
  doctorBody: string;
}

export const sendAppointmentReminders = onSchedule("every 30 minutes", async () => {
    const now = new Date();
    // Query window: appointments in the next 25 hours (catches day-before + soon buckets).
    const windowEnd = new Date(now.getTime() + 25 * 60 * 60 * 1000);

    const apptSnap = await db
      .collection("appointments")
      .where("status", "==", "confirmed")
      .where("scheduledAt", ">=", Timestamp.fromDate(now))
      .where("scheduledAt", "<=", Timestamp.fromDate(windowEnd))
      .get();

    const tasks: Promise<void>[] = apptSnap.docs.map((doc) =>
      _processApptReminder(doc, now)
    );
    await Promise.allSettled(tasks);
  });

async function _processApptReminder(
  apptDoc: admin.firestore.QueryDocumentSnapshot,
  now: Date
): Promise<void> {
  const appt = apptDoc.data();
  const scheduledAt = (appt.scheduledAt as Timestamp | undefined)?.toDate();
  if (!scheduledAt) return;

  const minutesUntil =
    (scheduledAt.getTime() - now.getTime()) / (60 * 1000);
  const hoursUntil = minutesUntil / 60;

  const reminders = (appt.reminders ?? {}) as Record<string, unknown>;
  const patientId = appt.patientId as string | undefined;
  const doctorId = appt.doctorId as string | undefined;
  const patientName = appt.patientName as string | undefined;

  if (!patientId || !doctorId) return;

  const updates: Record<string, unknown> = {};

  // Day-before window: 23.5h ≤ hoursUntil < 24.5h
  if (hoursUntil >= 23.5 && hoursUntil < 24.5 && !reminders.dayBeforeSentAt) {
    await _writeApptReminder({
      apptId: apptDoc.id,
      patientId,
      doctorId,
      patientName,
      patientTitle: "Appointment tomorrow",
      patientBody: "You have an appointment tomorrow. Make sure you're ready.",
      doctorTitle: "Appointment tomorrow",
      doctorBody: `${patientName ?? "A patient"} has an appointment with you tomorrow.`,
    });
    updates["reminders.dayBeforeSentAt"] = Timestamp.fromDate(now);
  }

  // Soon window: 0 ≤ minutesUntil < 30 (fires the ~15-min reminder on each 30-min poll cycle)
  if (minutesUntil >= 0 && minutesUntil < 30 && !reminders.soonSentAt) {
    await _writeApptReminder({
      apptId: apptDoc.id,
      patientId,
      doctorId,
      patientName,
      patientTitle: "Appointment in about 15 minutes",
      patientBody: "Your appointment starts in about 15 minutes. Head over now.",
      doctorTitle: "Appointment in about 15 minutes",
      doctorBody: `${patientName ?? "A patient"}'s appointment starts in about 15 minutes.`,
    });
    updates["reminders.soonSentAt"] = Timestamp.fromDate(now);
  }

  if (Object.keys(updates).length > 0) {
    await apptDoc.ref.update(updates);
  }
}

async function _writeApptReminder(p: _ApptReminderPayload): Promise<void> {
  const now = new Date();

  // Patient path: write notification doc → triggers sendPushOnNotification pipeline.
  await db
    .collection("patients")
    .doc(p.patientId)
    .collection("notifications")
    .add({
      type: "appointment",
      title: p.patientTitle,
      body: p.patientBody,
      apptId: p.apptId,
      createdAt: Timestamp.fromDate(now),
      read: false,
      pushSent: false,
    });

  // Doctor path: direct FCM (doctor has no notifications subcollection).
  const doctorDoc = await db.collection("users").doc(p.doctorId).get();
  const fcmToken = doctorDoc.data()?.fcmToken as string | undefined;
  if (!fcmToken) return;

  try {
    await messaging.send({
      token: fcmToken,
      notification: {title: p.doctorTitle, body: p.doctorBody},
      data: {
        channel: "appointment_reminders",
        apptId: p.apptId,
        patientId: p.patientId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "appointment_reminders",
          priority: "high",
          sound: "default",
        },
      },
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    functions.logger.warn("Doctor appointment FCM failed", {
      doctorId: p.doctorId,
      apptId: p.apptId,
      err,
    });
  }
}

/**
 * Clears reminders tracking fields when scheduledAt changes on a confirmed
 * appointment, so the rescheduled time receives fresh reminders.
 */
export const resetRemindersOnReschedule = onDocumentUpdated(
  "appointments/{apptId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeMs = (before.scheduledAt as Timestamp | undefined)?.toMillis();
    const afterMs = (after.scheduledAt as Timestamp | undefined)?.toMillis();
    if (beforeMs === afterMs) return;

    await event.data!.after.ref.update({
      reminders: admin.firestore.FieldValue.delete(),
    });
  }
);

async function _checkPatientMissedDoses(
  patientId: string,
  medDocs: admin.firestore.QueryDocumentSnapshot[],
  now: Date,
  windowStart: Date
): Promise<void> {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  for (const medDoc of medDocs) {
    const med = medDoc.data();
    const reminderTimes: string[] = med.reminderTimes ?? [];
    if (reminderTimes.length === 0) continue;

    const loggedDoses: Timestamp[] = med.loggedDoses ?? [];

    // Check each slot individually — a multi-dose medicine needs per-slot tracking.
    // A slot is "missed in this window" if:
    //   1. The slot time fell within [windowStart, now)
    //   2. No logged dose falls within that slot's 30-min coverage window
    const hasMissed = reminderTimes.some((t) => {
      const [hStr, mStr] = t.split(":");
      const slotTime = new Date(today);
      slotTime.setHours(parseInt(hStr, 10), parseInt(mStr ?? "0", 10), 0, 0);

      // Only consider slots that fell in this function's 30-min window.
      if (slotTime < windowStart || slotTime >= now) return false;

      // The slot's coverage window: [slotTime - 30 min, slotTime + 30 min).
      const coverStart = new Date(slotTime.getTime() - 30 * 60 * 1000);
      const coverEnd = new Date(slotTime.getTime() + 30 * 60 * 1000);

      const slotCovered = loggedDoses.some((ts) => {
        const d = ts.toDate();
        return d >= coverStart && d < coverEnd;
      });

      return !slotCovered;
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

      const caregiverDoc = await db.collection("users").doc(conn.caregiverUid).get();
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
        functions.logger.warn("Caregiver FCM send failed", {caregiverUid: conn.caregiverUid, err});
      }
    }
  }
}
