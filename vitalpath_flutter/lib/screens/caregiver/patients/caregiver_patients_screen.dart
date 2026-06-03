import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_connection.dart';

class CaregiverPatientsScreen extends ConsumerWidget {
  const CaregiverPatientsScreen({super.key});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

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

        final patientsAsync = ref.watch(caregiverPatientsProvider(user.uid));
        final pendingAsync =
            ref.watch(pendingInvitesForEmailProvider(user.email ?? ''));

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
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PENDING INVITES',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        ...pending.map((inv) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: BentoCard(
                                color: AppColors.inviteAccent
                                    .withValues(alpha: 0.07),
                                onTap: () =>
                                    context.go('/accept-invite', extra: inv),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.inviteAccent
                                        .withValues(alpha: 0.12),
                                    child: Text(_initials(inv.patientName),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inviteAccent)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(inv.patientName,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                            'Wants to share their health with you (as their ${inv.relationship.relationshipLabel})',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.mutedForeground)),
                                      ])),
                                  StatusBadge.warning('Pending'),
                                  const SizedBox(width: 6),
                                  HugeIcon(
                                      icon: HugeIcons.strokeRoundedArrowRight01,
                                      color: AppColors.textTertiary,
                                      size: 14),
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
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),

              patientsAsync.when(
                loading: () => const Center(
                    child: Padding(
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
                        HugeIcon(
                            icon: HugeIcons.strokeRoundedGroup,
                            color: AppColors.mutedForeground,
                            size: 36),
                        const SizedBox(height: 10),
                        const Text('No connected family members yet',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text(
                          'When family members invite you to view their health,\nthey will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 12),
                      ]),
                    );
                  }

                  return Column(
                    children: patients
                        .map((conn) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ConnectedPatientCard(conn: conn),
                            ))
                        .toList(),
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

enum _StatusDot { green, amber }

class _ConnectedPatientCard extends ConsumerWidget {
  final CaregiverConnection conn;
  const _ConnectedPatientCard({required this.conn});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(conn.patientId));
    _StatusDot? dot;
    if (medsAsync.hasValue) {
      final active = medsAsync.value!.where((m) => m.isActive).toList();
      if (active.isNotEmpty) {
        final anyDue = active.any(
            (m) => m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot);
        dot = anyDue ? _StatusDot.amber : _StatusDot.green;
      }
    }

    return BentoCard(
      onTap: () => context.go('/caregiver-patient-profile', extra: conn),
      child: Row(children: [
        Stack(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.caregiver.withValues(alpha: 0.12),
            child: Text(_initials(conn.patientName),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.caregiver)),
          ),
          if (dot != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Tooltip(
                message: dot == _StatusDot.green
                    ? 'All doses taken'
                    : 'Dose due soon',
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot == _StatusDot.green
                        ? AppColors.success
                        : AppColors.caregiver,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(conn.patientName,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(conn.relationship.relationshipLabel,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
        ])),
        HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: AppColors.textTertiary,
            size: 16),
      ]),
    );
  }
}
