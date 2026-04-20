import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { patient, doctor }

class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final UserType userType;
  final DateTime createdAt;
  final bool onboardingComplete;

  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    required this.userType,
    required this.createdAt,
    this.onboardingComplete = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      photoUrl: map['photoUrl'],
      userType: map['userType'] == 'doctor' ? UserType.doctor : UserType.patient,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      onboardingComplete: map['onboardingComplete'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'userType': userType.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'onboardingComplete': onboardingComplete,
      };

  AppUser copyWith({
    String? name, String? phone, String? email, String? photoUrl,
    UserType? userType, bool? onboardingComplete,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      userType: userType ?? this.userType,
      createdAt: createdAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
