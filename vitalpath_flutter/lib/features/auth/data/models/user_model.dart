import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.phone,
    super.name,
    super.avatarUrl,
    super.role,
    super.email,
    super.dateOfBirth,
    super.gender,
    super.primaryCondition,
    super.isOnboarded,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:               json['id'] as String,
    phone:            json['phone'] as String,
    name:             json['name'] as String?,
    avatarUrl:        json['avatar_url'] as String?,
    role:             json['role'] as String? ?? 'patient',
    email:            json['email'] as String?,
    dateOfBirth:      json['date_of_birth'] \!= null ? DateTime.parse(json['date_of_birth']) : null,
    gender:           json['gender'] as String?,
    primaryCondition: json['primary_condition'] as String?,
    isOnboarded:      json['is_onboarded'] as bool? ?? false,
    createdAt:        json['created_at'] \!= null ? DateTime.parse(json['created_at']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    if (name \!= null) 'name': name,
    if (avatarUrl \!= null) 'avatar_url': avatarUrl,
    'role': role,
    if (email \!= null) 'email': email,
    if (dateOfBirth \!= null) 'date_of_birth': dateOfBirth\!.toIso8601String(),
    if (gender \!= null) 'gender': gender,
    if (primaryCondition \!= null) 'primary_condition': primaryCondition,
    'is_onboarded': isOnboarded,
    'created_at': createdAt.toIso8601String(),
  };

  factory UserModel.fromEntity(UserEntity e) => UserModel(
    id: e.id, phone: e.phone, name: e.name, avatarUrl: e.avatarUrl,
    role: e.role, email: e.email, dateOfBirth: e.dateOfBirth,
    gender: e.gender, primaryCondition: e.primaryCondition,
    isOnboarded: e.isOnboarded, createdAt: e.createdAt,
  );
}
