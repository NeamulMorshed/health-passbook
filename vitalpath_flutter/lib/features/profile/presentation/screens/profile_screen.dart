import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Gradient hero
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          ),
                          child: Center(child: Text(
                            user?.name?.isNotEmpty == true ? user!.name![0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                          )),
                        ),
                        const SizedBox(height: 10),
                        Text(user?.name ?? 'Patient Name',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(user?.phone ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.65))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats row
                Row(
                  children: [
                    _StatTile(value: '47', label: 'Days active'),
                    const SizedBox(width: 10),
                    _StatTile(value: '85%', label: 'Adherence'),
                    const SizedBox(width: 10),
                    _StatTile(value: '3', label: 'Medications'),
                  ],
                ),
                const SizedBox(height: 16),

                // Switch to Doctor Portal
                InkWell(
                  onTap: () => context.go(AppConstants.routeDoctorRoster),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(children: [
                      Icon(Icons.medical_services_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Doctor Portal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Switch to doctor view', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ])),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // Settings list
                _SettingsTile(icon: Icons.notifications_rounded, label: 'Notifications', onTap: () {}),
                _SettingsTile(icon: Icons.lock_rounded, label: 'Privacy & Security', onTap: () {}),
                _SettingsTile(icon: Icons.help_rounded, label: 'Help & Support', onTap: () {}),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: AppColors.error,
                  onTap: () async {
                    await ref.read(authStateProvider.notifier).signOut();
                    if (context.mounted) context.go(AppConstants.routeLogin);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value, label;
  const _StatTile({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadows,
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text3, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppColors.cardShadows,
    ),
    child: ListTile(
      leading: Icon(icon, color: color ?? AppColors.text2, size: 22),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? AppColors.text1)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.text3),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
