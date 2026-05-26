import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';
import '../models/appointment_message.dart';

final _db = FirebaseFirestore.instance;

// ── Stream: messages for an appointment ──────────────────────────────────────
// Sorted oldest-first so the chat reads top-to-bottom; ListView reverses for
// the natural "newest at bottom" feel.

final appointmentMessagesProvider =
    StreamProvider.family<List<AppointmentMessage>, String>((ref, apptId) {
  return _db
      .collection('appointments')
      .doc(apptId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) {
    final out = <AppointmentMessage>[];
    for (final d in s.docs) {
      try {
        out.add(AppointmentMessage.fromMap(d.data(), d.id));
      } catch (_) {
        // ADR-003: skip malformed docs so one bad message doesn't kill the stream.
      }
    }
    return out;
  });
});

// ── Send a message ───────────────────────────────────────────────────────────
// Single batch write:
//   1. New message doc with participants denormalized for cheap rules
//   2. Appointment doc updated with lastMessageAt + lastMessagePreview
//   3. AppNotification to the recipient — picked up by the existing
//      sendPushOnNotification Cloud Function which fires the FCM push.

Future<void> sendAppointmentMessage({
  required String appointmentId,
  required String text,
  required String senderId,
  required SenderRole senderRole,
  required String senderName,
  required String patientId,
  required String doctorId,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;

  final recipientId = senderRole == SenderRole.patient ? doctorId : patientId;
  final batch = _db.batch();

  // 1. Message doc
  final msgRef = _db
      .collection('appointments')
      .doc(appointmentId)
      .collection('messages')
      .doc();
  batch.set(msgRef, AppointmentMessage(
    id: msgRef.id,
    text: trimmed,
    senderId: senderId,
    senderRole: senderRole,
    participants: [patientId, doctorId],
    createdAt: DateTime.now(),
  ).toMap());

  // 2. Denormalized preview on the appointment doc
  batch.update(_db.collection('appointments').doc(appointmentId), {
    'lastMessageAt': Timestamp.fromDate(DateTime.now()),
    'lastMessagePreview':
        trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed,
  });

  // 3. Notification → push via existing function
  final notifRef = _db
      .collection('users')
      .doc(recipientId)
      .collection('notifications')
      .doc();
  batch.set(notifRef, AppNotification(
    id: '',
    title: 'New message from $senderName',
    body: trimmed.length > 100 ? '${trimmed.substring(0, 100)}…' : trimmed,
    type: NotificationType.appointment,
    isRead: false,
    createdAt: DateTime.now(),
    data: {
      'appointmentId': appointmentId,
      'messageId': msgRef.id,
    },
  ).toMap());

  await batch.commit();
}

// ── Mark messages from the other party as read ───────────────────────────────
// Called when the current user opens the chat. Only patches unread messages
// from the OTHER role (you don't mark your own messages read).

Future<void> markAppointmentMessagesRead({
  required String appointmentId,
  required String currentUserId,
}) async {
  final unread = await _db
      .collection('appointments')
      .doc(appointmentId)
      .collection('messages')
      .where('readAt', isNull: true)
      .get();

  if (unread.docs.isEmpty) return;

  final batch = _db.batch();
  final now = Timestamp.fromDate(DateTime.now());
  var pending = 0;
  for (final d in unread.docs) {
    // Don't mark your own messages as read.
    if (d.data()['senderId'] == currentUserId) continue;
    batch.update(d.reference, {'readAt': now});
    pending++;
  }
  if (pending > 0) await batch.commit();
}
