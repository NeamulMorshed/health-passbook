import 'package:cloud_firestore/cloud_firestore.dart';

class ConsultationNote {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String note;
  final DateTime createdAt;

  const ConsultationNote({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.note,
    required this.createdAt,
  });

  factory ConsultationNote.fromMap(Map<String, dynamic> map, String id) {
    return ConsultationNote(
      id: id,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      note: map['note'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
