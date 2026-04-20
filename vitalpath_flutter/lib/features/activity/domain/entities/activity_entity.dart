import 'package:equatable/equatable.dart';

class ActivityEntity extends Equatable {
  final String id;
  final String patientId;
  final DateTime date;
  final int steps;
  final int? stepGoal;
  final double? distanceKm;
  final int? activeMinutes;
  final double? weightKg;      // §5.6 — validated on entry
  final int? bloodPressureSys;
  final int? bloodPressureDia;
  final int? heartRateBpm;
  final double? bloodGlucose;
  final double? spo2;
  final int? sleepMinutes;
  final List<String>? symptoms;
  final int? moodScore;        // 1–5

  const ActivityEntity({
    required this.id,
    required this.patientId,
    required this.date,
    required this.steps,
    this.stepGoal = 10000,
    this.distanceKm,
    this.activeMinutes,
    this.weightKg,
    this.bloodPressureSys,
    this.bloodPressureDia,
    this.heartRateBpm,
    this.bloodGlucose,
    this.spo2,
    this.sleepMinutes,
    this.symptoms,
    this.moodScore,
  });

  double get stepProgress => stepGoal \!= null && stepGoal\! > 0 ? (steps / stepGoal\!).clamp(0, 1) : 0;

  @override
  List<Object?> get props => [id, patientId, date];
}
