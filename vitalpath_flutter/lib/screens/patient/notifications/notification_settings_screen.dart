import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../providers/auth_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  static const _keyMeds    = 'notif_medicines';
  static const _keyMeals   = 'notif_meals';
  static const _keyAppts   = 'notif_appointments';
  static const _keyDoctors = 'notif_doctors';

  bool _medicines    = true;
  bool _meals        = true;
  bool _appointments = true;
  bool _doctors      = true;
  bool _loaded       = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _medicines    = prefs.getBool(_keyMeds)    ?? true;
      _meals        = prefs.getBool(_keyMeals)   ?? true;
      _appointments = prefs.getBool(_keyAppts)   ?? true;
      _doctors      = prefs.getBool(_keyDoctors) ?? true;
      _loaded       = true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Bug 5 fix: when a category is turned off, cancel all its pending notifications.
  Future<void> _onMedicinesToggle(bool value) async {
    setState(() => _medicines = value);
    await _save(_keyMeds, value);
    if (!value) {
      await ref
          .read(notificationServiceProvider)
          .cancelAllForChannel(AppConstants.notifChannelMedicine);
    }
  }

  Future<void> _onMealsToggle(bool value) async {
    setState(() => _meals = value);
    await _save(_keyMeals, value);
    if (!value) {
      // Meal reminders share the general channel — cancel tracked IDs only.
      await ref
          .read(notificationServiceProvider)
          .cancelAllForChannel(AppConstants.notifChannelGeneral);
    }
  }

  Future<void> _onAppointmentsToggle(bool value) async {
    setState(() => _appointments = value);
    await _save(_keyAppts, value);
    if (!value) {
      await ref
          .read(notificationServiceProvider)
          .cancelAllForChannel(AppConstants.notifChannelAppointment);
    }
  }

  Future<void> _onDoctorsToggle(bool value) async {
    setState(() => _doctors = value);
    await _save(_keyDoctors, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Notification Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                BentoSectionHeader(title: 'Reminders'),
                const SizedBox(height: 8),
                BentoCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    BentoSettingsTile(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedMedicine01,
                          color: AppColors.primary,
                          size: 20),
                      title: 'Medicine Reminders',
                      subtitle: "Notify when it's time to take your medicine",
                      trailing: Switch(
                        value: _medicines,
                        onChanged: _onMedicinesToggle,
                        activeThumbColor: AppColors.primary,
                      ),
                      showDivider: true,
                    ),
                    BentoSettingsTile(
                      icon: const Icon(Icons.restaurant_rounded,
                          color: AppColors.success, size: 20),
                      title: 'Meal Reminders',
                      subtitle: 'Reminders to log breakfast, lunch and dinner',
                      trailing: Switch(
                        value: _meals,
                        onChanged: _onMealsToggle,
                        activeThumbColor: AppColors.success,
                      ),
                      showDivider: false,
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                BentoSectionHeader(title: 'Health Updates'),
                const SizedBox(height: 8),
                BentoCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    BentoSettingsTile(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          color: AppColors.primary,
                          size: 20),
                      title: 'Appointment Alerts',
                      subtitle: 'When a doctor confirms, reschedules or cancels',
                      trailing: Switch(
                        value: _appointments,
                        onChanged: _onAppointmentsToggle,
                        activeThumbColor: AppColors.primary,
                      ),
                      showDivider: true,
                    ),
                    BentoSettingsTile(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedGroup,
                          color: AppColors.primary,
                          size: 20),
                      title: 'Doctor Updates',
                      subtitle: 'New prescriptions and updates from your doctors',
                      trailing: Switch(
                        value: _doctors,
                        onChanged: _onDoctorsToggle,
                        activeThumbColor: AppColors.primary,
                      ),
                      showDivider: false,
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Turning off a category cancels its pending reminders '
                  'and prevents new ones from being scheduled.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground),
                ),
              ],
            ),
    );
  }
}
