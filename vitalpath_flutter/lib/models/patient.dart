import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship = '',
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) =>
      EmergencyContact(
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        relationship: map['relationship'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  String get displayLine {
    final parts = [name, if (relationship.isNotEmpty) relationship].join(' · ');
    return parts;
  }
}

List<String> _parseAllergies(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  if (raw is String && raw.trim().isNotEmpty) {
    return raw
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return const [];
}

EmergencyContact? _parseEmergencyContact(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return EmergencyContact.fromMap(raw);
  // Legacy: old records stored just a phone number string — treat as phone-only.
  if (raw is String && raw.isNotEmpty) {
    return EmergencyContact(name: '', phone: raw);
  }
  return null;
}

class PatientProfile {
  final String uid;
  final String name;
  final DateTime? dateOfBirth;
  final int? _legacyAge; // retained for records that predate DOB field
  final double? weight; // kg
  final double? height; // cm
  final String? bloodType;
  final List<String> conditions;
  final List<String> allergies;
  final EmergencyContact? emergencyContact;
  final String? doctorId;

  const PatientProfile({
    required this.uid,
    required this.name,
    this.dateOfBirth,
    int? legacyAge,
    this.weight,
    this.height,
    this.bloodType,
    this.conditions = const [],
    this.allergies = const [],
    this.emergencyContact,
    this.doctorId,
  }) : _legacyAge = legacyAge;

  // Dynamically computed from DOB; falls back to legacy stored age.
  int? get age {
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int years = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        years--;
      }
      return years;
    }
    return _legacyAge;
  }

  double? get bmi => (weight != null && height != null && height! > 0)
      ? weight! / ((height! / 100) * (height! / 100))
      : null;

  factory PatientProfile.fromMap(Map<String, dynamic> map, String uid) {
    return PatientProfile(
      uid: uid,
      name: map['name'] ?? '',
      dateOfBirth: (map['dateOfBirth'] as Timestamp?)?.toDate(),
      legacyAge: map['age'] as int?,
      weight: (map['weight'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      bloodType: map['bloodType'],
      conditions: List<String>.from(map['conditions'] ?? []),
      allergies: _parseAllergies(map['allergies']),
      emergencyContact: _parseEmergencyContact(map['emergencyContact']),
      doctorId: map['doctorId'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        // Store computed age for backward compat with queries that read 'age'.
        'age': age,
        'dateOfBirth':
            dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'weight': weight,
        'height': height,
        'bloodType': bloodType,
        'conditions': conditions,
        'allergies': allergies,
        'emergencyContact': emergencyContact?.toMap(),
        'doctorId': doctorId,
      };
}
