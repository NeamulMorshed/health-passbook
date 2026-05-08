import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HydrationNotifier extends StateNotifier<int> {
  HydrationNotifier() : super(0) {
    _load();
  }

  static String get _todayKey =>
      'hydration_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_todayKey) ?? 0;
  }

  Future<void> addCup() async {
    if (state >= 8) return;
    final prefs = await SharedPreferences.getInstance();
    final next = state + 1;
    await prefs.setInt(_todayKey, next);
    state = next;
  }

  Future<void> removeCup() async {
    if (state <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final next = state - 1;
    await prefs.setInt(_todayKey, next);
    state = next;
  }
}

final hydrationProvider =
    StateNotifierProvider.autoDispose<HydrationNotifier, int>((ref) {
  return HydrationNotifier();
});
