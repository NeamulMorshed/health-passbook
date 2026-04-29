import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notification Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),

                _SettingsSection(
                  title: 'Reminders',
                  children: [
                    _ToggleTile(
                      icon: Icons.medication_rounded,
                      color: AppColors.primary,
                      title: 'Medicine Reminders',
                      subtitle: 'Notify when it\'s time to take your medicine',
                      value: _medicines,
                      onChanged: (v) {
                        setState(() => _medicines = v);
                        _save(_keyMeds, v);
                      },
                    ),
                    _ToggleTile(
                      icon: Icons.restaurant_rounded,
                      color: AppColors.success,
                      title: 'Meal Reminders',
                      subtitle: 'Reminders to log breakfast, lunch and dinner',
                      value: _meals,
                      onChanged: (v) {
                        setState(() => _meals = v);
                        _save(_keyMeals, v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _SettingsSection(
                  title: 'Health Updates',
                  children: [
                    _ToggleTile(
                      icon: Icons.calendar_month_rounded,
                      color: AppColors.doctorPrimary,
                      title: 'Appointment Alerts',
                      subtitle:
                          'When a doctor confirms, reschedules or cancels',
                      value: _appointments,
                      onChanged: (v) {
                        setState(() => _appointments = v);
                        _save(_keyAppts, v);
                      },
                    ),
                    _ToggleTile(
                      icon: Icons.people_rounded,
                      color: AppColors.doctorPrimary,
                      title: 'Doctor Updates',
                      subtitle: 'New prescriptions and updates from your doctors',
                      value: _doctors,
                      onChanged: (v) {
                        setState(() => _doctors = v);
                        _save(_keyDoctors, v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Changes take effect immediately. Disabling a category '
                    'cancels any scheduled reminders for that type.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
                letterSpacing: 0.5,
                fontFamily: 'Inter'),
          ),
        ),
        Container(
          color: AppColors.surface,
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [
                  children[i],
                  if (i < children.length - 1)
                    const Divider(height: 1, indent: 60, color: AppColors.border),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter')),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
              fontFamily: 'Inter')),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: color,
      ),
    );
  }
}
