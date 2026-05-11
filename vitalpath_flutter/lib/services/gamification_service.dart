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
    // G1: Wrap in Firestore transaction to prevent race conditions.
    return await _db.runTransaction<int>((tx) async {
      final ref = _db.collection(_col).doc(uid);
      final snap = await tx.get(ref);
      final profile = (snap.exists && snap.data() != null)
          ? GamificationProfile.fromMap(snap.data()!)
          : const GamificationProfile();

      // G3: Use UTC for stored timestamps.
      final now = DateTime.now().toUtc();

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
      tx.set(ref, updated.toMap(), SetOptions(merge: false));
      return hpGain;
    });
  }

  Future<int> awardMealLog(String uid) async {
    // G1: Wrap in Firestore transaction to prevent race conditions.
    return await _db.runTransaction<int>((tx) async {
      final ref = _db.collection(_col).doc(uid);
      final snap = await tx.get(ref);
      final profile = (snap.exists && snap.data() != null)
          ? GamificationProfile.fromMap(snap.data()!)
          : const GamificationProfile();

      if (_isToday(profile.lastMealDate)) return 0;

      // G3: Use UTC for stored timestamps.
      final now = DateTime.now().toUtc();

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
      tx.set(ref, updated.toMap(), SetOptions(merge: false));
      return hpGain;
    });
  }

  Future<int> awardActivity(String uid, {required int steps, required String type}) async {
    // G1: Wrap in Firestore transaction to prevent race conditions.
    return await _db.runTransaction<int>((tx) async {
      final ref = _db.collection(_col).doc(uid);
      final snap = await tx.get(ref);
      final profile = (snap.exists && snap.data() != null)
          ? GamificationProfile.fromMap(snap.data()!)
          : const GamificationProfile();

      if (_isToday(profile.lastActivityDate)) return 0;

      // G3: Use UTC for stored timestamps.
      final now = DateTime.now().toUtc();

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
      tx.set(ref, updated.toMap(), SetOptions(merge: false));
      return hpGain;
    });
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    // G3: Convert stored UTC date to local before comparing.
    final local = date.toLocal();
    final now = DateTime.now();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  bool _isYesterday(DateTime? date) {
    if (date == null) return false;
    // G3: Convert stored UTC date to local before comparing.
    final local = date.toLocal();
    // G2: DST-safe yesterday using calendar arithmetic.
    final n = DateTime.now();
    final yesterday = DateTime(n.year, n.month, n.day - 1);
    return local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day;
  }

  GamificationProfile _resetWeekIfNeeded(GamificationProfile profile, DateTime now) {
    final weekStart = profile.weekStartDate;
    // G5: Calendar-based week reset — compare calendar dates, not raw duration.
    final today = DateTime(now.year, now.month, now.day);
    final storedDay = weekStart != null
        ? DateTime(weekStart.year, weekStart.month, weekStart.day)
        : null;
    if (storedDay == null || today.difference(storedDay).inDays >= 7) {
      // G3: Use UTC for weekStart.
      final nowLocal = now.toLocal();
      final monday = nowLocal.subtract(Duration(days: nowLocal.weekday - 1));
      return profile.copyWith(
        weeklyMedDays: 0,
        weeklyMealDays: 0,
        weeklyActivityDays: 0,
        weekStartDate: DateTime.utc(monday.year, monday.month, monday.day),
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
