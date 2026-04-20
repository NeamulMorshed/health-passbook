import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// User profile screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppConstants.routeSettings),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profile not found'));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Avatar
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (profile.displayName ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.displayName ?? 'User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      profile.phoneNumber,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Health stats
              _ProfileSection(
                title: 'Health Information',
                items: [
                  _ProfileItem(
                    icon: Icons.height_rounded,
                    label: 'Height',
                    value: profile.heightCm != null
                        ? '${profile.heightCm!.toInt()} cm'
                        : 'Not set',
                  ),
                  _ProfileItem(
                    icon: Icons.monitor_weight_rounded,
                    label: 'Weight',
                    value: profile.weightKg != null
                        ? '${profile.weightKg!.toStringAsFixed(1)} kg'
                        : 'Not set',
                  ),
                  _ProfileItem(
                    icon: Icons.bloodtype_rounded,
                    label: 'Blood Type',
                    value: profile.bloodType ?? 'Not set',
                  ),
                  _ProfileItem(
                    icon: Icons.fitness_center_rounded,
                    label: 'Daily Step Goal',
                    value: '${profile.stepGoal} steps',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Account actions
              _ProfileSection(
                title: 'Account',
                items: [
                  _ProfileItem(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    value: '',
                    onTap: () => context.push(AppConstants.routeSettings),
                  ),
                  _ProfileItem(
                    icon: Icons.privacy_tip_rounded,
                    label: 'Privacy & Data',
                    value: '',
                    onTap: () => context.push(AppConstants.routeSettings),
                  ),
                  _ProfileItem(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete Account',
                    value: '',
                    valueColor: AppColors.error,
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sign out
              ElevatedButton(
                onPressed: () => _signOut(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.08),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently erase all your health data. This action cannot be undone (GDPR Right to be Forgotten).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Implement full account deletion (GDPR §6.2)
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(phoneAuthNotifierProvider.notifier).signOut();
    if (context.mounted) context.go(AppConstants.routeSplash);
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: valueColor ?? AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
