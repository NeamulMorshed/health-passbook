import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/appointment.dart';

class DocDashboardScreen extends ConsumerWidget {
  const DocDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: 'Pull to refresh or try again.',
      ))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        final docAsync          = ref.watch(doctorProfileProvider(user.uid));
        final apptsAsync        = ref.watch(doctorAppointmentsProvider(user.uid));
        final patientCountAsync = ref.watch(doctorPatientCountProvider(user.uid));

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                ),
                Text(
                  user.name.startsWith('Dr.') ? user.name : 'Dr. ${user.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                docAsync.when(
                  data: (doc) => Text(
                    doc?.specialty ?? 'Doctor',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load',
              subtitle: 'Unable to load appointments. Pull to refresh.',
            )),
            data: (appts) {
              final pending      = appts.where((a) => a.isPending).toList();
              final confirmed    = appts.where((a) => a.isConfirmed).toList();
              final patientCount = patientCountAsync.asData?.value ?? 0;
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd = todayStart.add(const Duration(days: 1));
              final todayCount = confirmed.where((a) =>
                  a.scheduledAt != null &&
                  !a.scheduledAt!.isBefore(todayStart) &&
                  a.scheduledAt!.isBefore(todayEnd)).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Row(children: [
                    Expanded(child: BentoStatCard(
                      label: 'Patients',
                      value: '$patientCount',
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedGroup, color: AppColors.primary, size: 18),
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primary,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: BentoStatCard(
                      label: 'Today',
                      value: '$todayCount',
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: AppColors.info, size: 18),
                      iconBgColor: AppColors.infoLight,
                      iconColor: AppColors.info,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: BentoStatCard(
                      label: 'Pending',
                      value: '${pending.length}',
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: AppColors.warning, size: 18),
                      iconBgColor: AppColors.warningLight,
                      iconColor: AppColors.warning,
                    )),
                  ]),
                  const SizedBox(height: 24),

                  // Quick actions
                  Row(children: [
                    _ActionTile(
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedGroup, color: AppColors.primary, size: 22),
                      label: 'Patients',
                      color: AppColors.primary,
                      onTap: () => context.go('/doc/patients'),
                    ),
                    const SizedBox(width: 12),
                    _ActionTile(
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: AppColors.primary, size: 22),
                      label: 'Appointments',
                      color: AppColors.primary,
                      onTap: () => context.go('/doc/appointments'),
                    ),
                    const SizedBox(width: 12),
                    _ActionTile(
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit01, color: AppColors.success, size: 22),
                      label: 'Prescribe',
                      color: AppColors.success,
                      onTap: () => context.go('/doc/patients', extra: {'mode': 'prescribe'}),
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
                          child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: AppColors.success, size: 32),
                        ),
                        const SizedBox(height: 10),
                        const Text('All caught up', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text(
                          'No pending appointment requests.',
                          style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                        ),
                      ]),
                    )
                  else
                    Column(
                      children: pending.take(5).map((a) => _PendingApptCard(appt: a)).toList(),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _ActionTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BentoCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          icon,
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appt.patientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (appt.patientNote != null && appt.patientNote!.isNotEmpty)
              Text(
                appt.patientNote!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
              ),
          ])),
          StatusBadge.warning('Pending'),
          const SizedBox(width: 4),
          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.mutedForeground, size: 14),
        ]),
      ),
    );
  }
}
