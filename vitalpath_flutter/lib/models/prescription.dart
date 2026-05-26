import 'package:cloud_firestore/cloud_firestore.dart';

class PrescribedMed {
  final String name;
  final String dosage;
  final String frequency;
  final String? instructions;

  const PrescribedMed(
      {required this.name,
      required this.dosage,
      required this.frequency,
      this.instructions});

  factory PrescribedMed.fromMap(Map<String, dynamic> map) => PrescribedMed(
        name: map['name'] ?? '',
        dosage: map['dosage'] ?? '',
        frequency: map['frequency'] ?? '',
        instructions: map['instructions'],
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'instructions': instructions,
      };
}

class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final List<PrescribedMed> medicines;
  final String? diagnosis;
  final String? notes;
  final DateTime issuedAt;
  final String? documentUrl;

  const Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.medicines,
    this.diagnosis,
    this.notes,
    required this.issuedAt,
    this.documentUrl,
  });

  factory Prescription.fromMap(Map<String, dynamic> map, String id) {
    return Prescription(
      id: id,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      medicines: (map['medicines'] as List<dynamic>?)
              ?.map((m) => PrescribedMed.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      diagnosis: map['diagnosis'],
      notes: map['notes'],
      issuedAt: (map['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      documentUrl: map['documentUrl'],
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'medicines': medicines.map((m) => m.toMap()).toList(),
        'diagnosis': diagnosis,
        'notes': notes,
        'issuedAt': Timestamp.fromDate(issuedAt),
        'documentUrl': documentUrl,
      };
}
