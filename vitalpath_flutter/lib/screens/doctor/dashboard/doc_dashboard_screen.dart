import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../providers/doctor_attention_provider.dart';
import '../../../models/app_user.dart';
import '../../../models/appointment.dart';
import '../../../models/patient_attention.dart';
import '../../../core/widgets/freshness_timestamp.dart';
import '../../../core/widgets/status_hero_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/utils/greeting.dart';

final _docLastRefreshedProvider =
    StateProvider<DateTime>((_) => DateTime.now());

class DocDashboardScreen extends ConsumerWidget {
  const DocDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: SafeArea(child: DashboardSkeleton())),
      error: (_, __) => const Scaffold(
          body: Center(
              child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: 'Pull to refresh or try again.',
      ))),
      data: (user) {
        if (user == null || user.userType != UserType.doctor) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (user?.userType == UserType.caregiver) {
              context.go('/caregiver/home');
            } else if (user?.userType == UserType.patient) {
              context.go('/home');
            } else {
              context.go('/user-select');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        final docAsync = ref.watch(doctorProfileProvider(user.uid));
        final apptsAsync = ref.watch(doctorAppointmentsProvider(user.uid));
        final patientCountAsync =
            ref.watch(doctorPatientCountProvider(user.uid));

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingForHour(),
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400),
                ),
                Text(
                  user.name.startsWith('Dr.') ? user.name : 'Dr. ${user.name}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                docAsync.when(
                  data: (doc) => Text(
                    doc?.specialty ?? 'Doctor',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AppAvatar(
                  name: user.name,
                  size: 38,
                  imageUrl: user.photoUrl,
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
          body: apptsAsync.when(
            loading: () => const DashboardSkeleton(),
            error: (e, __) => Center(
                child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load',
              subtitle: 'Unable to load appointments. Pull to refresh.',
            )),
            data: (appts) {
              final pending = appts.where((a) => a.isPending).toList();
              final confirmed = appts.where((a) => a.isConfirmed).toList();
              final patientCount = patientCountAsync.asData?.value ?? 0;
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd = todayStart.add(const Duration(days: 1));
              final todayCount = confirmed
                  .where((a) =>
                      a.scheduledAt != null &&
                      !a.scheduledAt!.isBefore(todayStart) &&
                      a.scheduledAt!.isBefore(todayEnd))
                  .length;

              final todayAppts = [...confirmed, ...pending]
                  .where((a) =>
                      a.scheduledAt != null &&
                      !a.scheduledAt!.isBefore(todayStart) &&
                      a.scheduledAt!.isBefore(todayEnd))
                  .toList()
                ..sort((x, y) => x.scheduledAt!.compareTo(y.scheduledAt!));
              final scheduleRows = todayAppts
                  .map((a) => ScheduleRow(
                        time: DateFormat('HH:mm').format(a.scheduledAt!),
                        name: a.patientName,
                        status: a.isConfirmed ? 'Confirmed' : 'Pending',
                        confirmed: a.isConfirmed,
                      ))
                  .toList();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(patientsNeedingAttentionProvider(user.uid));
                  ref.invalidate(doctorAppointmentsProvider(user.uid));
                  ref.read(_docLastRefreshedProvider.notifier).state =
                      DateTime.now();
                  if (context.mounted) {
                    AppSnackBar.info(context, 'Updated just now');
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('EEEE, MMMM d').format(DateTime.now()),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textTertiary),
                          ),
                          FreshnessTimestamp(
                              lastUpdated:
                                  ref.watch(_docLastRefreshedProvider)),
                        ]),
                    const SizedBox(height: 16),

                    // Stats
                    Row(children: [
                      Expanded(
                          child: BentoStatCard(
                        label: 'Patients',
                        value: '$patientCount',
                        icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedGroup,
                            color: AppColors.primary,
                            size: 18),
                        iconBgColor: AppColors.primaryTint,
                        iconColor: AppColors.primary,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: BentoStatCard(
                        label: 'Today',
                        value: '$todayCount',
                        icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar01,
                            color: AppColors.info,
                            size: 18),
                        iconBgColor: AppColors.infoLight,
                        iconColor: AppColors.info,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: BentoStatCard(
                        label: 'Pending',
                        value: '${pending.length}',
                        icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedClock01,
                            color: AppColors.warning,
                            size: 18),
                        iconBgColor: AppColors.warningLight,
                        iconColor: AppColors.warning,
                      )),
                    ]),
                    const SizedBox(height: 16),

                    // Today's schedule hero (closes G-4: list, not just a count)
                    StatusHeroCard.schedule(
                      dateLabel: DateFormat('EEE, MMM d').format(DateTime.now()),
                      rows: scheduleRows,
                      onOpen: () => context.go('/doc/appointments'),
                    ),
                    const SizedBox(height: 24),

                    // Needs Attention (position #3 per Dr. Rahman persona)
                    if (patientCount > 0) ...[
                      _NeedsAttentionSection(doctorId: user.uid),
                      const SizedBox(height: 24),
                    ],

                    // Quick actions
                    Row(children: [
                      _ActionTile(
                        icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedGroup,
                            color: AppColors.primary,
                            size: 22),
                        label: 'Patients',
                        color: AppColors.primary,
                        onTap: () => context.go('/doc/patients'),
                      ),
                      const SizedBox(width: 12),
                      _ActionTile(
                        icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar01,
                            color: AppColors.primary,
                            size: 22),
                        label: 'Appointments',
                        color: AppColors.primary,
                        onTap: () => context.go('/doc/appointments'),
                      ),
                      const SizedBox(width: 12),
                      _ActionTile(
                        icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedPencilEdit01,
                            color: AppColors.success,
                            size: 22),
                        label: 'Prescribe',
                        color: AppColors.success,
                        onTap: () => context
                            .go('/doc/patients', extra: {'mode': 'prescribe'}),
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // Recent requests
                    BentoSectionHeader(
                      title: 'Recent Requests',
                      action: 'See all',
                      onAction: () => context.go('/doc/appointments'),
                    ),
                    const SizedBox(height: 12),

                    if (pending.isEmpty)
                      BentoCard(
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                                color: AppColors.success,
                                size: 32),
                          ),
                          const SizedBox(height: 10),
                          const Text('All caught up',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text(
                            'No pending appointment requests.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.mutedForeground),
                          ),
                        ]),
                      )
                    else
                      Column(
                        children: pending
                            .take(5)
                            .map((a) => _PendingApptCard(appt: a))
                            .toList(),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

}

class _ActionTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BentoCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          icon,
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

// ─── Needs Attention Section ──────────────────────────────────────────────────

class _NeedsAttentionSection extends ConsumerWidget {
  final String doctorId;
  const _NeedsAttentionSection({required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attentionAsync =
        ref.watch(patientsNeedingAttentionProvider(doctorId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoSectionHeader(
          title: 'Needs Attention',
          action: 'See all',
          onAction: () => context.go('/doc/patients'),
        ),
        const SizedBox(height: 12),
        attentionAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => BentoCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 18, color: AppColors.mutedForeground),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Could not load patient data.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.mutedForeground),
                ),
              ),
            ]),
          ),
          data: (items) {
            if (items.isEmpty) {
              return BentoCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        color: AppColors.success,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('All patients on track',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success)),
                          SizedBox(height: 2),
                          Text('No adherence or vitals issues detected.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground)),
                        ]),
                  ),
                ]),
              );
            }
            return Column(
              children: items
                  .take(5)
                  .map((a) => _PatientAttentionTile(attention: a))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PatientAttentionTile extends ConsumerWidget {
  final PatientAttention attention;
  const _PatientAttentionTile({required this.attention});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        onTap: () => context.go('/doc/patients/${attention.patientId}'),
        child: Row(children: [
          AppAvatar(name: attention.patientName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attention.patientName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (attention.adherencePct != null &&
                        attention.adherencePct! < 50)
                      _Pill(
                        label:
                            '${attention.adherencePct!.toStringAsFixed(0)}% adherence · 7-day',
                        color: AppColors.warning,
                      ),
                    if (attention.abnormalVitalsCount > 0)
                      _Pill(
                        label: _abnormalPillLabel(attention),
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.mutedForeground,
              size: 14),
        ]),
      ),
    );
  }
}

// G-5 explainability: surface the most-recent abnormal reading + when it happened.
String _abnormalPillLabel(PatientAttention a) {
  final base = a.mostRecentAbnormalLabel ??
      '${a.abnormalVitalsCount} abnormal vital${a.abnormalVitalsCount == 1 ? '' : 's'}';
  final at = a.mostRecentAbnormalAt;
  return at == null ? base : '$base · ${_relativeTime(at)}';
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return 'just now';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays}d ago';
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─── Pending Appointment Card ─────────────────────────────────────────────────

class _PendingApptCard extends ConsumerWidget {
  final Appointment appt;
  const _PendingApptCard({required this.appt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        onTap: () => context.go('/doc/appointments'),
        child: Row(children: [
          AppAvatar(name: appt.patientName, size: 40),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(appt.patientName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (appt.patientNote != null && appt.patientNote!.isNotEmpty)
                  Text(
                    appt.patientNote!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground),
                  ),
              ])),
          StatusBadge.warning('Pending'),
          const SizedBox(width: 4),
          HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.mutedForeground,
              size: 14),
        ]),
      ),
    );
  }
}
