import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  final String id;
  final String name;
  final String relationship;
  final DateTime? dateOfBirth;
  final int? _legacyAge;
  final String? photoUrl;
  final DateTime createdAt;
  final String profileType; // 'dependent' | 'linked'
  final String? linkedUid;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    this.dateOfBirth,
    int? legacyAge,
    this.photoUrl,
    required this.createdAt,
    this.profileType = 'dependent',
    this.linkedUid,
  }) : _legacyAge = legacyAge;

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

  factory FamilyMember.fromMap(Map<String, dynamic> map, String id) {
    return FamilyMember(
      id: id,
      name: map['name'] as String? ?? '',
      relationship: map['relationship'] as String? ?? 'Other',
      dateOfBirth: (map['dateOfBirth'] as Timestamp?)?.toDate(),
      legacyAge: map['age'] as int?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileType: map['profileType'] as String? ?? 'dependent',
      linkedUid: map['linkedUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'relationship': relationship,
        'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'age': age,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'profileType': profileType,
        if (linkedUid != null) 'linkedUid': linkedUid,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
