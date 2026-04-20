import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String frequency;
  final String? prescribedBy;
  final String? doctorId;
  final String? notes;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final List<DateTime> loggedDoses; // timestamps of taken doses

  const Medicine({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.prescribedBy,
    this.doctorId,
    this.notes,
    this.isActive = true,
    required this.startDate,
    this.endDate,
    this.loggedDoses = const [],
  });

  bool get takenToday {
    final today = DateTime.now();
    return loggedDoses.any((d) =>
        d.year == today.year && d.month == today.month && d.day == today.day);
  }

  factory Medicine.fromMap(Map<String, dynamic> map, String id) {
    return Medicine(
      id: id,
      patientId: map['patientId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      prescribedBy: map['prescribedBy'],
      doctorId: map['doctorId'],
      notes: map['notes'],
      isActive: map['isActive'] ?? true,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      loggedDoses: (map['loggedDoses'] as List<dynamic>?)
              ?.map((t) => (t as Timestamp).toDate())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'prescribedBy': prescribedBy,
        'doctorId': doctorId,
        'notes': notes,
        'isActive': isActive,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate \!= null ? Timestamp.fromDate(endDate\!) : null,
        'loggedDoses': loggedDoses.map((d) => Timestamp.fromDate(d)).toList(),
      };
}
