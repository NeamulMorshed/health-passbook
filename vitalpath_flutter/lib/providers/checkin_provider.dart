import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CheckinState {
  final bool isCheckedInToday;
  final String? sleepQuality; // 'well' | 'okay' | 'poorly'
  final String? feeling; // 'great' | 'good' | 'off' | 'unwell'

  const CheckinState({
    required this.isCheckedInToday,
    this.sleepQuality,
    this.feeling,
  });
}

class CheckinNotifier extends StateNotifier<CheckinState> {
  CheckinNotifier() : super(const CheckinState(isCheckedInToday: false)) {
    _load();
  }

  static String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('checkin_done_$_today') ?? false;
    final sleep = prefs.getString('checkin_sleep_$_today');
    final feeling = prefs.getString('checkin_feeling_$_today');
    state = CheckinState(
        isCheckedInToday: done, sleepQuality: sleep, feeling: feeling);
  }

  Future<void> checkIn(
      {required String sleepQuality, required String feeling}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('checkin_done_$_today', true);
    await prefs.setString('checkin_sleep_$_today', sleepQuality);
    await prefs.setString('checkin_feeling_$_today', feeling);
    state = CheckinState(
        isCheckedInToday: true, sleepQuality: sleepQuality, feeling: feeling);
  }
}

final checkinProvider =
    StateNotifierProvider.autoDispose<CheckinNotifier, CheckinState>((ref) {
  return CheckinNotifier();
});
