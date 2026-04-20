import 'package:equatable/equatable.dart';

/// Medicine entity — pure domain object, decoupled from Drift/Supabase.
class MedicineEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String unit;
  final double dosage;
  final String frequency;
  final List<String> scheduledTimes;
  final List<String> scheduledDays;
  final DateTime startDate;
  final DateTime? endDate;
  final int inventoryCount;
  final int refillThreshold;
  final String? imagePath;
  final String? notes;
  final String colorHex;
  final bool isVerified;
  final String? doctorConnectionId;
  final bool isActive;
  final DateTime createdAt;

  const MedicineEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.unit,
    required this.dosage,
    required this.frequency,
    required this.scheduledTimes,
    required this.scheduledDays,
    required this.startDate,
    this.endDate,
    required this.inventoryCount,
    required this.refillThreshold,
    this.imagePath,
    this.notes,
    required this.colorHex,
    required this.isVerified,
    this.doctorConnectionId,
    required this.isActive,
    required this.createdAt,
  });

  bool get needsRefill => inventoryCount <= refillThreshold;

  String get dosageDisplay =>
      '${dosage.toStringAsFixed(dosage.truncateToDouble() == dosage ? 0 : 1)} $unit';

  String get nextDoseTime =>
      scheduledTimes.isNotEmpty ? scheduledTimes.first : '--:--';

  @override
  List<Object?> get props => [id, userId, name, dosage, unit, frequency];
}

/// Medicine frequency options
enum MedicineFrequency {
  daily('daily', 'Daily'),
  twiceDaily('twice_daily', 'Twice Daily'),
  thriceDaily('thrice_daily', 'Three Times Daily'),
  weekly('weekly', 'Weekly'),
  asNeeded('as_needed', 'As Needed');

  final String value;
  final String label;

  const MedicineFrequency(this.value, this.label);

  static MedicineFrequency fromValue(String value) =>
      MedicineFrequency.values.firstWhere((f) => f.value == value,
          orElse: () => MedicineFrequency.daily);
}

/// Medicine unit options
enum MedicineUnit {
  pills('pills', 'Pills'),
  tablet('tablet', 'Tablet'),
  capsule('capsule', 'Capsule'),
  mg('mg', 'mg'),
  ml('ml', 'ml'),
  drops('drops', 'Drops'),
  puff('puff', 'Puff (Inhaler)');

  final String value;
  final String label;

  const MedicineUnit(this.value, this.label);

  static MedicineUnit fromValue(String value) =>
      MedicineUnit.values.firstWhere((u) => u.value == value,
          orElse: () => MedicineUnit.pills);
}
