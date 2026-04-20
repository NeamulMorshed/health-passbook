import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/user_profile_table.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  Future<UserProfile?> getProfile(String userId) {
    return (select(userProfiles)..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
  }

  Stream<UserProfile?> watchProfile(String userId) {
    return (select(userProfiles)..where((u) => u.id.equals(userId)))
        .watchSingleOrNull();
  }

  Future<void> upsertProfile(UserProfilesCompanion profile) {
    return into(userProfiles)
        .insert(profile, mode: InsertMode.insertOrReplace);
  }

  Future<int> updateStepGoal(String userId, int goal) {
    return (update(userProfiles)..where((u) => u.id.equals(userId)))
        .write(UserProfilesCompanion(stepGoal: Value(goal)));
  }

  Future<int> markOnboardingComplete(String userId) {
    return (update(userProfiles)..where((u) => u.id.equals(userId)))
        .write(const UserProfilesCompanion(
            onboardingCompleted: Value(true)));
  }

  Future<int> deleteProfile(String userId) {
    return (delete(userProfiles)..where((u) => u.id.equals(userId))).go();
  }
}
