import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserType { patient, doctor, caregiver }

class AppUser {
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

  final String uid;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final UserType userType;
  final DateTime createdAt;
  final bool onboardingComplete;

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Builds an [AppUser] from a Firestore document map + its document ID.
  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Unknown',
      phone: (map['phone'] as String?) ?? '',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      userType: _parseUserType(map['userType']),
      createdAt: _parseTimestamp(map['createdAt']),
      onboardingComplete: (map['onboardingComplete'] as bool?) ?? false,
    );
  }

  /// Creates a minimal [AppUser] from a freshly signed-in [User].
  /// Used when Google Sign-In succeeds but no Firestore profile exists yet;
  /// the caller still needs to pick a [userType] before writing to Firestore.
  factory AppUser.fromFirebaseUser(
    User firebaseUser, {
    required UserType userType,
    String phone = '',
  }) {
    return AppUser(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? firebaseUser.email ?? 'Unknown',
      phone: phone,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      userType: userType,
      createdAt: DateTime.now(),
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'userType': userType.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'onboardingComplete': onboardingComplete,
      };

  // ── Immutable updates ─────────────────────────────────────────────────────

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
    UserType? userType,
    bool? onboardingComplete,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppUser && other.uid == uid);

  @override
  int get hashCode => uid.hashCode;

  // ── Private helpers ───────────────────────────────────────────────────────

  static UserType _parseUserType(dynamic value) {
    if (value == 'doctor') return UserType.doctor;
    if (value == 'caregiver') return UserType.caregiver;
    return UserType.patient;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
