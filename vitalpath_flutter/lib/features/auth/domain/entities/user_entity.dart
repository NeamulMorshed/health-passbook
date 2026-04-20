import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class UserEntity extends Equatable {
  final String id;
  final String phone;
  final String? name;
  final String? avatarUrl;
  final String role;               // UserRole.patient | UserRole.doctor
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? primaryCondition;
  final bool isOnboarded;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.phone,
    this.name,
    this.avatarUrl,
    this.role = UserRole.patient,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.primaryCondition,
    this.isOnboarded = false,
    required this.createdAt,
  });

  bool get isPatient => role == UserRole.patient;
  bool get isDoctor  => role == UserRole.doctor;
  bool get isLoggedIn => id.isNotEmpty;

  UserEntity copyWith({
    String? name, String? avatarUrl, String? role,
    String? email, DateTime? dateOfBirth, String? gender,
    String? primaryCondition, bool? isOnboarded,
  }) => UserEntity(
    id: id, phone: phone, createdAt: createdAt,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    role: role ?? this.role,
    email: email ?? this.email,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    primaryCondition: primaryCondition ?? this.primaryCondition,
    isOnboarded: isOnboarded ?? this.isOnboarded,
  );

  static UserEntity empty() => UserEntity(id: '', phone: '', createdAt: DateTime.now());

  @override
  List<Object?> get props => [id, phone, name, role, email];
}
