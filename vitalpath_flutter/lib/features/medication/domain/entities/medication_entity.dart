import 'package:equatable/equatable.dart';

class MedicationEntity extends Equatable {
  final String id;
  final String patientId;
  final String name;
  final String dosage;           // e.g. "500mg"
  final String frequency;        // e.g. "Twice daily"
  final List<DateTime> scheduledTimes;   // times for today
  final String? instructions;
  final bool isVerified;         // §4.4 — doctor-verified
  final String? prescribedBy;    // doctor name
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final bool isActive;
  final String? color;           // pill colour tag
  final String? iconType;        // 'pill' | 'capsule' | 'liquid' | 'injection'
  final int? remainingCount;
  final int? totalCount;
  final DateTime? nextRefillDate;

  const MedicationEntity({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.scheduledTimes,
    this.instructions,
    this.isVerified = false,
    this.prescribedBy,
    this.verifiedAt,
    required this.createdAt,
    this.isActive = true,
    this.color,
    this.iconType = 'pill',
    this.remainingCount,
    this.totalCount,
    this.nextRefillDate,
  });

  bool get needsRefill {
    if (remainingCount == null || totalCount == null) return false;
    return remainingCount! / totalCount! <= 0.2;
  }

  @override
  List<Object?> get props => [id, name, dosage, patientId];
}
