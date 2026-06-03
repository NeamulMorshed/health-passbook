import 'package:cloud_firestore/cloud_firestore.dart';

enum SenderRole {
  patient('patient'),
  doctor('doctor');

  const SenderRole(this.value);
  final String value;

  static SenderRole fromString(String? value) =>
      value == 'doctor' ? SenderRole.doctor : SenderRole.patient;
}

class AppointmentMessage {
  final String id;
  final String text;
  final String senderId;
  final SenderRole senderRole;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppointmentMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderRole,
    required this.participants,
    required this.createdAt,
    this.readAt,
  });

  factory AppointmentMessage.fromMap(Map<String, dynamic> map, String id) {
    return AppointmentMessage(
      id: id,
      text: (map['text'] as String?) ?? '',
      senderId: (map['senderId'] as String?) ?? '',
      senderRole: SenderRole.fromString(map['senderRole'] as String?),
      participants:
          (map['participants'] as List?)?.cast<String>() ?? const <String>[],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'senderId': senderId,
        'senderRole': senderRole.value,
        'participants': participants,
        'createdAt': Timestamp.fromDate(createdAt),
        if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      };
}
