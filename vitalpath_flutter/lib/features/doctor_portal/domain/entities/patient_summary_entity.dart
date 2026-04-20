import 'package:equatable/equatable.dart';

class PatientSummaryEntity extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? primaryCondition;
  final double adherenceRate;    // 0.0 – 1.0 (7-day)
  final List<bool> weeklyDots;   // 7-item adherence dot grid
  final int activePrescriptions;
  final int pendingPrescriptions;
  final DateTime? lastSyncAt;
  final bool isConnected;
  final String? riskLevel;       // 'low' | 'medium' | 'high'

  const PatientSummaryEntity({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    this.primaryCondition,
    required this.adherenceRate,
    required this.weeklyDots,
    required this.activePrescriptions,
    this.pendingPrescriptions = 0,
    this.lastSyncAt,
    this.isConnected = false,
    this.riskLevel = 'low',
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth\!.year;
    if (now.month < dateOfBirth\!.month || (now.month == dateOfBirth\!.month && now.day < dateOfBirth\!.day)) age--;
    return age;
  }

  @override
  List<Object?> get props => [id, name, adherenceRate];
}

class SyncSessionEntity extends Equatable {
  final String code;
  final DateTime expiresAt;
  final String doctorId;
  final String? patientId;
  final bool isConnected;

  const SyncSessionEntity({
    required this.code,
    required this.expiresAt,
    required this.doctorId,
    this.patientId,
    this.isConnected = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingSeconds => expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 600);

  @override
  List<Object?> get props => [code, doctorId, isConnected];
}
