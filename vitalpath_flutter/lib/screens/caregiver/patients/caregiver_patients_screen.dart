import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../models/caregiver_connection.dart';

class CaregiverPatientsScreen extends ConsumerWidget {
  const CaregiverPatientsScreen({super.key});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.',
        )),
      ),
      data: (user) {
        if (user == null) return const Scaffold(body: SizedBox.shrink());

        final patientsAsync = ref.watch(caregiverPatientsProvider(user.uid));
        final pendingAsync  = ref.watch(pendingInvitesForEmailProvider(user.email ?? ''));

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('My Family'),
            actions: const [NotifBell()],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [

              // ── Pending invites ─────────────────────────────────────────
              pendingAsync.when(
                data: (pending) {
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('PENDING INVITES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary, letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    ...pending.map((inv) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BentoCard(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                        onTap: () => context.go('/accept-invite', extra: inv),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            child: Text(_initials(inv.patientName),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: Color(0xFF7C3AED))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(inv.patientName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('Wants to share their health with you (as their ${inv.relationship.relationshipLabel})',
                                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          ])),
                          StatusBadge.warning('Pending'),
                          const SizedBox(width: 6),
                          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                              color: AppColors.textTertiary, size: 14),
                        ]),
                      ),
                    )),
                    const SizedBox(height: 20),
                  ]);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // ── Connected family ──────────────────────────────────────
              const Text('CONNECTED FAMILY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary, letterSpacing: 0.8)),
              const SizedBox(height: 8),

              patientsAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )),
                error: (_, __) => const EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Error',
                  subtitle: 'Could not load family members. Pull to refresh.',
                ),
                data: (patients) {
                  if (patients.isEmpty) {
                    return BentoCard(
                      child: Column(children: [
                        const SizedBox(height: 12),
                        HugeIcon(icon: HugeIcons.strokeRoundedGroup,
                            color: AppColors.mutedForeground, size: 36),
                        const SizedBox(height: 10),
                        const Text('No connected family members yet',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text(
                          'When family members invite you to view their health,\nthey will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 12),
                      ]),
                    );
                  }

                  return Column(
                    children: patients.map((conn) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BentoCard(
                        onTap: () => context.go('/caregiver-patient-profile', extra: conn),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.caregiver.withValues(alpha: 0.12),
                            child: Text(_initials(conn.patientName),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AppColors.caregiver)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(conn.patientName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(conn.relationship.relationshipLabel,
                                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          ])),
                          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                              color: AppColors.textTertiary, size: 16),
                        ]),
                      ),
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
