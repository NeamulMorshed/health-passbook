import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamification.dart';

class GamificationService {
  final FirebaseFirestore _db;
  static const _col = 'gamification';

  GamificationService(this._db);

  Stream<GamificationProfile> watchProfile(String uid) {
    return _db.collection(_col).doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return const GamificationProfile();
      return GamificationProfile.fromMap(snap.data()!);
    });
  }

  // Called once per slot taken. Awards +10 HP up to a daily cap of 5 doses (50 HP/day).
  // Streak and weekly counter only advance on the first dose of each calendar day.
  Future<int> awardMedicineDose(String uid) async {
    final profile = await _getOrCreate(uid);
    final now = DateTime.now();

    const hpGain = 10;
    const dailyCap = 5;

    final isNewDay = !_isToday(profile.lastMedDate);
    final currentDailyCount = isNewDay ? 0 : profile.dailyMedDoses;
    if (currentDailyCount >= dailyCap) return 0;

    final weekReset = _resetWeekIfNeeded(profile, now);

    var updated = weekReset.copyWith(
      hp: weekReset.hp + hpGain,
      dailyMedDoses: currentDailyCount + 1,
      medStreak: isNewDay
          ? (_isYesterday(profile.lastMedDate) ? profile.medStreak + 1 : 1)
          : weekReset.medStreak,
      lastMedDate: isNewDay ? now : weekReset.lastMedDate,
      weeklyMedDays: isNewDay
          ? weekReset.weeklyMedDays + 1
          : weekReset.weeklyMedDays,
    );

    updated = _applyBadges(updated, 'med');
    await _save(uid, updated);
    return hpGain;
  }

  Future<int> awardMealLog(String uid) async {
    final profile = await _getOrCreate(uid);
    final now = DateTime.now();

    if (_isToday(profile.lastMealDate)) return 0;

    const hpGain = 8;
    final newStreak = _isYesterday(profile.lastMealDate) ? profile.mealStreak + 1 : 1;
    final weekReset = _resetWeekIfNeeded(profile, now);
    final newWeeklyMeal = weekReset.weeklyMealDays + 1;

    var updated = weekReset.copyWith(
      hp: profile.hp + hpGain,
      mealStreak: newStreak,
      lastMealDate: now,
      weeklyMealDays: newWeeklyMeal,
    );

    updated = _applyBadges(updated, 'meal');
    await _save(uid, updated);
    return hpGain;
  }

  Future<int> awardActivity(String uid, {required int steps, required String type}) async {
    final profile = await _getOrCreate(uid);
    final now = DateTime.now();

    if (_isToday(profile.lastActivityDate)) return 0;

    final hpGain = steps >= 5000 ? 25 : 15;
    final newStreak = _isYesterday(profile.lastActivityDate) ? profile.activityStreak + 1 : 1;
    final weekReset = _resetWeekIfNeeded(profile, now);
    final newWeeklyActivity = weekReset.weeklyActivityDays + 1;

    var updated = weekReset.copyWith(
      hp: profile.hp + hpGain,
      activityStreak: newStreak,
      lastActivityDate: now,
      weeklyActivityDays: newWeeklyActivity,
    );

    updated = _applyBadges(updated, 'activity');
    await _save(uid, updated);
    return hpGain;
  }

  Future<GamificationProfile> _getOrCreate(String uid) async {
    final snap = await _db.collection(_col).doc(uid).get();
    if (!snap.exists || snap.data() == null) return const GamificationProfile();
    return GamificationProfile.fromMap(snap.data()!);
  }

  Future<void> _save(String uid, GamificationProfile profile) async {
    await _db.collection(_col).doc(uid).set(profile.toMap(), SetOptions(merge: false));
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime? date) {
    if (date == null) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  GamificationProfile _resetWeekIfNeeded(GamificationProfile profile, DateTime now) {
    final weekStart = profile.weekStartDate;
    if (weekStart == null || now.difference(weekStart).inDays >= 7) {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      return profile.copyWith(
        weeklyMedDays: 0,
        weeklyMealDays: 0,
        weeklyActivityDays: 0,
        weekStartDate: DateTime(monday.year, monday.month, monday.day),
      );
    }
    return profile;
  }

  GamificationProfile _applyBadges(GamificationProfile profile, String action) {
    final earned = List<String>.from(profile.badgeIds);

    void award(String id) {
      if (!earned.contains(id)) earned.add(id);
    }

    if (action == 'med') {
      award('med_first');
      if (profile.medStreak >= 7) award('med_7');
    }
    if (action == 'meal') {
      award('meal_first');
      if (profile.mealStreak >= 7) award('meal_7');
    }
    if (action == 'activity') {
      award('active_first');
      if (profile.activityStreak >= 5) award('activity_5');
    }

    final combined = (profile.medStreak > 0 ? 1 : 0) +
        (profile.mealStreak > 0 ? 1 : 0) +
        (profile.activityStreak > 0 ? 1 : 0);
    if (combined >= 3) award('streak_shield');

    if (profile.hp >= 500) award('hp_500');
    if (profile.hp >= 1000) award('hp_1000');

    return profile.copyWith(badgeIds: earned);
  }
}
