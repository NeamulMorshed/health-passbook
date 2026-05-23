import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  pending('pending'),
  confirmed('confirmed'),
  completed('completed'),
  cancelled('cancelled');

  const AppointmentStatus(this.value);
  final String value;

  static AppointmentStatus fromString(String? value) => switch (value) {
    'confirmed' => AppointmentStatus.confirmed,
    'completed'  => AppointmentStatus.completed,
    'cancelled'  => AppointmentStatus.cancelled,
    _            => AppointmentStatus.pending,
  };
}

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String? doctorSpecialty;
  final AppointmentStatus status;
  final DateTime? scheduledAt;
  final String? notes;
  final String? patientNote;
  final DateTime createdAt;
  final int? patientRating;
  final String? familyMemberId;
  final String? familyMemberName;

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
    this.patientRating,
    this.familyMemberId,
    this.familyMemberName,
  });

  bool get isPending   => status == AppointmentStatus.pending;
  bool get isConfirmed => status == AppointmentStatus.confirmed;
  bool get isCompleted => status == AppointmentStatus.completed;
  bool get isCancelled => status == AppointmentStatus.cancelled;

  factory Appointment.fromMap(Map<String, dynamic> map, String id) {
    return Appointment(
      id:               id,
      patientId:        map['patientId']      ?? '',
      patientName:      map['patientName']    ?? '',
      doctorId:         map['doctorId']       ?? '',
      doctorName:       map['doctorName']     ?? '',
      doctorSpecialty:  map['doctorSpecialty'],
      status:           AppointmentStatus.fromString(map['status']),
      scheduledAt:      (map['scheduledAt'] as Timestamp?)?.toDate(),
      notes:            map['notes'],
      patientNote:      map['patientNote'],
      createdAt:        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      patientRating:    (map['patientRating'] as num?)?.toInt(),
      familyMemberId:   map['familyMemberId'] as String?,
      familyMemberName: map['familyMemberName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'patientId':       patientId,
    'patientName':     patientName,
    'doctorId':        doctorId,
    'doctorName':      doctorName,
    'doctorSpecialty': doctorSpecialty,
    'status':          status.value,
    'scheduledAt':     scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
    'notes':           notes,
    'patientNote':     patientNote,
    'createdAt':       Timestamp.fromDate(createdAt),
    'patientRating':   patientRating,
    if (familyMemberId != null) 'familyMemberId': familyMemberId,
    if (familyMemberName != null) 'familyMemberName': familyMemberName,
  };

  Appointment copyWith({
    AppointmentStatus? status,
    DateTime? scheduledAt,
    String? notes,
  }) {
    return Appointment(
      id:               id,
      patientId:        patientId,
      patientName:      patientName,
      doctorId:         doctorId,
      doctorName:       doctorName,
      doctorSpecialty:  doctorSpecialty,
      status:           status ?? this.status,
      scheduledAt:      scheduledAt ?? this.scheduledAt,
      notes:            notes ?? this.notes,
      patientNote:      patientNote,
      createdAt:        createdAt,
      familyMemberId:   familyMemberId,
      familyMemberName: familyMemberName,
    );
  }
}
