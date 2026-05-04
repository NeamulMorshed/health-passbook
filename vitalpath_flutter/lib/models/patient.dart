
class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship = '',
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) => EmergencyContact(
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

EmergencyContact? _parseEmergencyContact(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return EmergencyContact.fromMap(raw);
  if (raw is String && raw.isNotEmpty) {
    return EmergencyContact(name: raw, phone: raw);
  }
  return null;
}

class PatientProfile {
  final String uid;
  final String name;
  final int? age;
  final double? weight; // kg
  final double? height; // cm
  final String? bloodType;
  final List<String> conditions;
  final String? allergies;
  final EmergencyContact? emergencyContact;
  final String? doctorId;

  const PatientProfile({
    required this.uid,
    required this.name,
    this.age,
    this.weight,
    this.height,
    this.bloodType,
    this.conditions = const [],
    this.allergies,
    this.emergencyContact,
    this.doctorId,
  });

  double? get bmi => (weight != null && height != null && height! > 0)
      ? weight! / ((height! / 100) * (height! / 100))
      : null;

  factory PatientProfile.fromMap(Map<String, dynamic> map, String uid) {
    return PatientProfile(
      uid: uid,
      name: map['name'] ?? '',
      age: map['age'],
      weight: (map['weight'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      bloodType: map['bloodType'],
      conditions: List<String>.from(map['conditions'] ?? []),
      allergies: map['allergies'],
      emergencyContact: _parseEmergencyContact(map['emergencyContact']),
      doctorId: map['doctorId'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'bloodType': bloodType,
        'conditions': conditions,
        'allergies': allergies,
        'emergencyContact': emergencyContact?.toMap(),
        'doctorId': doctorId,
      };
}
