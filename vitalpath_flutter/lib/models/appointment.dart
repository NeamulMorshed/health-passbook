import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String? doctorSpecialty;
  final String status; // pending, confirmed, completed, cancelled
  final DateTime? scheduledAt;
  final String? notes;
  final String? patientNote;
  final DateTime createdAt;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    this.doctorSpecialty,
    required this.status,
    this.scheduledAt,
    this.notes,
    this.patientNote,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  factory Appointment.fromMap(Map<String, dynamic> map, String id) {
    return Appointment(
      id: id,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      doctorSpecialty: map['doctorSpecialty'],
      status: map['status'] ?? 'pending',
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      notes: map['notes'],
      patientNote: map['patientNote'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorSpecialty': doctorSpecialty,
        'status': status,
        'scheduledAt': scheduledAt \!= null ? Timestamp.fromDate(scheduledAt\!) : null,
        'notes': notes,
        'patientNote': patientNote,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Appointment copyWith({String? status, DateTime? scheduledAt, String? notes}) {
    return Appointment(
      id: id, patientId: patientId, patientName: patientName,
      doctorId: doctorId, doctorName: doctorName, doctorSpecialty: doctorSpecialty,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      notes: notes ?? this.notes,
      patientNote: patientNote,
      createdAt: createdAt,
    );
  }
}
