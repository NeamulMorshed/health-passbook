import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_connection.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';

class CaregiverProfileScreen extends ConsumerWidget {
  const CaregiverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(
            child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.',
        )),
      ),
      data: (user) {
        if (user == null || user.userType != UserType.caregiver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (user?.userType == UserType.doctor) {
              context.go('/doc/dashboard');
            } else if (user?.userType == UserType.patient) {
              context.go('/home');
            } else {
              context.go('/user-select');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final connections =
            ref.watch(caregiverPatientsProvider(user.uid)).asData?.value ?? [];
        const badgeLabel = 'Family Member';

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('My Profile'),
            actions: const [NotifBell()],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // ── Profile header ───────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                child: Column(children: [
                  AppAvatar(name: user.name, size: 72, imageUrl: user.photoUrl),
                  const SizedBox(height: 12),
                  Text(
                    user.name.isNotEmpty ? user.name : 'Family Member',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.caregiver.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.caregiver.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.caregiver),
                    ),
                  ),
                  if (user.phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(user.phone,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.mutedForeground)),
                  ],
                ]),
              ),

              const SizedBox(height: 20),

              // ── People I'm monitoring ─────────────────────────────────────
              if (connections.isNotEmpty) ...[
                _SectionLabel('PEOPLE I\'M MONITORING'),
                const SizedBox(height: 8),
                BentoCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: connections.asMap().entries.map((entry) {
                      final i = entry.key;
                      final conn = entry.value;
                      final initials = _initials(conn.patientName);
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppColors.caregiver.withValues(alpha: 0.12),
                              child: Text(initials,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.caregiver)),
                            ),
                            title: Text(conn.patientName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(conn.relationship.relationshipLabel,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground)),
                            trailing: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                color: AppColors.textTertiary,
                                size: 14),
                            onTap: () => context
                                .go('/caregiver-patient-profile', extra: conn),
                          ),
                          if (i < connections.length - 1)
                            const Divider(
                                height: 1, indent: 56, color: AppColors.border),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Settings ─────────────────────────────────────────────────
              _SectionLabel('SETTINGS'),
              const SizedBox(height: 8),
              BentoCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  BentoSettingsTile(
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedPencilEdit01,
                        color: AppColors.textPrimary,
                        size: 18),
                    title: 'Edit Profile',
                    onTap: () => context.push('/edit-profile'),
                  ),
                  BentoSettingsTile(
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedBellDot,
                        color: AppColors.textPrimary,
                        size: 18),
                    title: 'Notifications',
                    onTap: () => context.push('/notification-settings'),
                  ),
                  BentoSettingsTile(
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedLock,
                        color: AppColors.textPrimary,
                        size: 18),
                    title: 'Privacy',
                    showDivider: false,
                    onTap: () => context.push('/privacy-security'),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Account ──────────────────────────────────────────────────
              _SectionLabel('ACCOUNT'),
              const SizedBox(height: 8),
              BentoCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  BentoSettingsTile(
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedQuestion,
                        color: AppColors.textPrimary,
                        size: 18),
                    title: 'Help & Support',
                    showDivider: false,
                    onTap: () =>
                        launchUrl(Uri.parse('mailto:support@omra.health')),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Sign out ──────────────────────────────────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedLogout01,
                      color: AppColors.destructive,
                      size: 18),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                        color: AppColors.destructive,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.destructive),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                try {
                  await ref.read(authRepositoryProvider).signOut();
                } catch (_) {}
                if (context.mounted) context.go('/user-select');
              },
              child: const Text('Sign Out'),
            ),
            const SizedBox(height: 4),
            Center(
                child: TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            )),
          ]),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
        ),
      );
}
