import 'package:drift/drift.dart';

/// Local user profile cache — mirrors Supabase users table.
class UserProfiles extends Table {
  TextColumn get id => text()();

  TextColumn get phoneNumber => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  /// Height in centimeters
  RealColumn get heightCm => real().nullable()();

  /// Weight in kilograms
  RealColumn get weightKg => real().nullable()();

  /// Health condition tags: JSON array ["Type 2 Diabetes", "Hypertension"]
  TextColumn get conditions => text().withDefault(const Constant('[]'))();

  /// Blood type: 'A+' | 'A-' | 'B+' | 'B-' | 'AB+' | 'AB-' | 'O+' | 'O-'
  TextColumn get bloodType => text().nullable()();

  /// Date of birth stored as "yyyy-MM-dd"
  TextColumn get dateOfBirth => text().nullable()();

  /// 'km' | 'miles'
  TextColumn get unitPreference =>
      text().withDefault(const Constant('km'))();

  /// Daily step goal
  IntColumn get stepGoal =>
      integer().withDefault(const Constant(10000))();

  /// Home timezone identifier (e.g., "America/New_York") — SRS §5.2 Timezone Leap
  TextColumn get homeTimezone => text().nullable()();

  /// Notification preferences: JSON object
  TextColumn get notificationPrefs =>
      text().withDefault(const Constant('{}'))();

  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
