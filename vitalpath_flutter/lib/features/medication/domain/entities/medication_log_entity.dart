import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class MedicationLogEntity extends Equatable {
  final String id;
  final String medicationId;
  final String patientId;
  final DateTime scheduledAt;    // what time it was supposed to be taken
  final DateTime? loggedAt;      // when patient actually logged it
  final String status;           // MedicationStatus.*
  final String? source;          // LogEntrySource.*
  final String? notes;
  final bool isDuplicate;        // flagged by §5.2 check
  final String? timezone;        // IANA timezone at time of logging

  const MedicationLogEntity({
    required this.id,
    required this.medicationId,
    required this.patientId,
    required this.scheduledAt,
    this.loggedAt,
    this.status = MedicationStatus.upcoming,
    this.source,
    this.notes,
    this.isDuplicate = false,
    this.timezone,
  });

  bool get isCompleted  => status == MedicationStatus.completed;
  bool get isOverdue    => status == MedicationStatus.overdue;
  bool get isInProgress => status == MedicationStatus.inProgress;

  MedicationLogEntity copyWith({String? status, DateTime? loggedAt, String? source, bool? isDuplicate}) =>
      MedicationLogEntity(
        id: id, medicationId: medicationId, patientId: patientId,
        scheduledAt: scheduledAt,
        loggedAt: loggedAt ?? this.loggedAt,
        status: status ?? this.status,
        source: source ?? this.source,
        notes: notes, isDuplicate: isDuplicate ?? this.isDuplicate, timezone: timezone,
      );

  @override
  List<Object?> get props => [id, medicationId, scheduledAt, status];
}
