import '../../domain/entities/medication_entity.dart';
import '../../domain/entities/medication_log_entity.dart';

class MedicationModel extends MedicationEntity {
  const MedicationModel({
    required super.id,
    required super.patientId,
    required super.name,
    required super.dosage,
    required super.frequency,
    required super.scheduledTimes,
    super.instructions,
    super.isVerified,
    super.prescribedBy,
    super.verifiedAt,
    required super.createdAt,
    super.isActive,
    super.color,
    super.iconType,
    super.remainingCount,
    super.totalCount,
    super.nextRefillDate,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    final times = (json['scheduled_times'] as List<dynamic>? ?? [])
        .map((t) => DateTime.parse(t as String))
        .toList();
    return MedicationModel(
      id:              json['id'] as String,
      patientId:       json['patient_id'] as String,
      name:            json['name'] as String,
      dosage:          json['dosage'] as String,
      frequency:       json['frequency'] as String,
      scheduledTimes:  times,
      instructions:    json['instructions'] as String?,
      isVerified:      json['is_verified'] as bool? ?? false,
      prescribedBy:    json['prescribed_by'] as String?,
      verifiedAt:      json['verified_at'] \!= null ? DateTime.parse(json['verified_at']) : null,
      createdAt:       DateTime.parse(json['created_at'] as String),
      isActive:        json['is_active'] as bool? ?? true,
      color:           json['color'] as String?,
      iconType:        json['icon_type'] as String? ?? 'pill',
      remainingCount:  json['remaining_count'] as int?,
      totalCount:      json['total_count'] as int?,
      nextRefillDate:  json['next_refill_date'] \!= null ? DateTime.parse(json['next_refill_date']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'patient_id': patientId, 'name': name,
    'dosage': dosage, 'frequency': frequency,
    'scheduled_times': scheduledTimes.map((t) => t.toIso8601String()).toList(),
    if (instructions \!= null) 'instructions': instructions,
    'is_verified': isVerified,
    if (prescribedBy \!= null) 'prescribed_by': prescribedBy,
    if (verifiedAt \!= null) 'verified_at': verifiedAt\!.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'is_active': isActive,
    if (color \!= null) 'color': color,
    'icon_type': iconType,
    if (remainingCount \!= null) 'remaining_count': remainingCount,
    if (totalCount \!= null) 'total_count': totalCount,
    if (nextRefillDate \!= null) 'next_refill_date': nextRefillDate\!.toIso8601String(),
  };
}

class MedicationLogModel extends MedicationLogEntity {
  const MedicationLogModel({
    required super.id,
    required super.medicationId,
    required super.patientId,
    required super.scheduledAt,
    super.loggedAt,
    super.status,
    super.source,
    super.notes,
    super.isDuplicate,
    super.timezone,
  });

  factory MedicationLogModel.fromJson(Map<String, dynamic> json) => MedicationLogModel(
    id:           json['id'] as String,
    medicationId: json['medication_id'] as String,
    patientId:    json['patient_id'] as String,
    scheduledAt:  DateTime.parse(json['scheduled_at'] as String),
    loggedAt:     json['logged_at'] \!= null ? DateTime.parse(json['logged_at']) : null,
    status:       json['status'] as String? ?? 'upcoming',
    source:       json['source'] as String?,
    notes:        json['notes'] as String?,
    isDuplicate:  json['is_duplicate'] as bool? ?? false,
    timezone:     json['timezone'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'medication_id': medicationId, 'patient_id': patientId,
    'scheduled_at': scheduledAt.toIso8601String(),
    if (loggedAt \!= null) 'logged_at': loggedAt\!.toIso8601String(),
    'status': status,
    if (source \!= null) 'source': source,
    if (notes \!= null) 'notes': notes,
    'is_duplicate': isDuplicate,
    if (timezone \!= null) 'timezone': timezone,
  };
}
