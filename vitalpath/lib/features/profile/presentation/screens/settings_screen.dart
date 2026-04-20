import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// App settings screen — notifications, preferences, privacy (SRS §6.2).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Notifications'),
          _SettingsTile(
            icon: Icons.alarm_rounded,
            title: 'Daily Outlook',
            subtitle: 'Morning health summary notification',
            trailing: Switch(
              value: true,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.medication_rounded,
            title: 'Medicine Reminders',
            subtitle: 'Alerts for each scheduled dose',
            trailing: Switch(
              value: true,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.restaurant_rounded,
            title: 'Meal Reminders',
            subtitle: '15-minute pre-meal alerts',
            trailing: Switch(
              value: true,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_active_rounded,
            title: 'Critical Alerts',
            subtitle: 'Override silent mode for urgent health alerts',
            trailing: Switch(
              value: false,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),

          const _SectionHeader(title: 'Activity'),
          _SettingsTile(
            icon: Icons.flag_rounded,
            title: 'Daily Step Goal',
            subtitle: '${AppConstants.defaultStepGoal} steps',
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          _SettingsTile(
            icon: Icons.straighten_rounded,
            title: 'Distance Unit',
            subtitle: 'Kilometers',
            trailing: const Icon(Icons.chevron_right_rounded),
          ),

          const _SectionHeader(title: 'Privacy & Security'),
          _SettingsTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric Lock',
            subtitle: 'Lock app when moving to background',
            trailing: Switch(
              value: true,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.cloud_sync_rounded,
            title: 'Sync Status',
            subtitle: 'All data synced',
            trailing: const Icon(Icons.check_circle_rounded, color: AppColors.success),
          ),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Export My Data',
            subtitle: 'Download all your health records',
            trailing: const Icon(Icons.chevron_right_rounded),
          ),

          const _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: 'VitalPath v${AppConstants.appVersion}',
            trailing: const SizedBox.shrink(),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'HIPAA & GDPR compliant',
            trailing: const Icon(Icons.open_in_new_rounded, size: 16),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
