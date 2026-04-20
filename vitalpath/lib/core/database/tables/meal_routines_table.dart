import 'package:drift/drift.dart';

/// Meal routines table — defines the user's eating schedule (SRS §4.2).
class MealRoutines extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// Display name: "Breakfast", "Lunch", "Dinner", "Snack"
  TextColumn get mealName => text().withLength(min: 1, max: 100)();

  /// Start of meal window: stored as "HH:mm" string
  TextColumn get windowStart => text()();

  /// End of meal window: stored as "HH:mm" string
  TextColumn get windowEnd => text()();

  /// Optional description
  TextColumn get description => text().nullable()();

  /// Nutritional tags: JSON array ["Low Sodium", "Diabetic Friendly", "High Protein"]
  TextColumn get nutritionalTags => text().withDefault(const Constant('[]'))();

  /// Active days: JSON array ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
  TextColumn get activeDays =>
      text().withDefault(const Constant('["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]'))();

  /// Calories target (optional)
  IntColumn get targetCalories => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Logs each meal event
class MealLogs extends Table {
  TextColumn get id => text()();
  TextColumn get mealRoutineId => text().references(MealRoutines, #id)();
  TextColumn get userId => text()();

  /// 'logged' | 'skipped' | 'snoozed'
  TextColumn get action => text()();

  DateTimeColumn get scheduledAt => dateTime()();
  DateTimeColumn get loggedAt => dateTime()();

  /// Optional notes (e.g., what was actually eaten)
  TextColumn get notes => text().nullable()();

  /// Actual calories consumed (optional)
  IntColumn get actualCalories => integer().nullable()();

  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
