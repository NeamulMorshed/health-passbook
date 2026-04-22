import 'package:cloud_firestore/cloud_firestore.dart';

class MealLog {
  final String id;
  final String patientId;
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final String description;
  final int? calories;
  final double? protein; // grams
  final double? carbs;   // grams
  final double? fat;     // grams
  final DateTime loggedAt;
  final String? photoUrl;
  final String? reminderTime; // "HH:mm" e.g. "07:30", null if no reminder

  const MealLog({
    required this.id,
    required this.patientId,
    required this.mealType,
    required this.description,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    required this.loggedAt,
    this.photoUrl,
    this.reminderTime,
  });

  factory MealLog.fromMap(Map<String, dynamic> map, String id) {
    return MealLog(
      id: id,
      patientId: map['patientId'] ?? '',
      mealType: map['mealType'] ?? 'Snack',
      description: map['description'] ?? '',
      calories: map['calories'],
      protein: (map['protein'] as num?)?.toDouble(),
      carbs: (map['carbs'] as num?)?.toDouble(),
      fat: (map['fat'] as num?)?.toDouble(),
      loggedAt: (map['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: map['photoUrl'],
      reminderTime: map['reminderTime'],
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'mealType': mealType,
        'description': description,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'loggedAt': Timestamp.fromDate(loggedAt),
        'photoUrl': photoUrl,
        'reminderTime': reminderTime,
      };
}
