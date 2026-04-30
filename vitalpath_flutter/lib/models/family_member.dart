import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  final String id;
  final String name;
  final String relationship;
  final int? age;
  final String? photoUrl;
  final DateTime createdAt;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    this.age,
    this.photoUrl,
    required this.createdAt,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> map, String id) {
    return FamilyMember(
      id: id,
      name: map['name'] as String? ?? '',
      relationship: map['relationship'] as String? ?? 'Other',
      age: map['age'] as int?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'relationship': relationship,
        'age': age,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
