import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
      error: (_, __) => const Scaffold(body: Center(child: EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        final docAsync = ref.watch(doctorProfileProvider(user.uid));
        final apptsAsync = ref.watch(doctorAppointmentsProvider(user.uid));

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.doctorPrimary, Color(0xFF5B21B6)]),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_greeting(), style: const TextStyle(fontSize: 13, color: Colors.white70, fontFamily: 'Inter')),
                            const SizedBox(height: 2),
                            Text('Dr. ${user.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Inter')),
                            docAsync.when(
                              data: (doc) => Text(doc?.specialty ?? 'Doctor', style: const TextStyle(fontSize: 13, color: Colors.white70, fontFamily: 'Inter')),
                              loading: () => const SizedBox(),
                              error: (_, __) => const SizedBox(),
                            ),
                          ])),
                          AppAvatar(name: user.name, size: 48, imageUrl: user.photoUrl, backgroundColor: Colors.white),
                        ]),
                        const SizedBox(height: 20),
                        Text(DateFormat('EEEE, MMMM d').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.white60, fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(delegate: SliverChildListDelegate([
                    // Stats cards
                    apptsAsync.when(
                      data: (appts) {
                        final pending = appts.where((a) => a.isPending).length;
                        final confirmed = appts.where((a) => a.isConfirmed).length;

                        return docAsync.when(
                          data: (doc) {
                            final patientCount = doc?.patientIds.length ?? 0;
                            return Row(children: [
                              Expanded(child: _StatTile('$patientCount', 'Patients', Icons.people_rounded, AppColors.primary)),
                              const SizedBox(width: 10),
                              Expanded(child: _StatTile('$pending', 'Pending', Icons.pending_actions_rounded, AppColors.warning)),
                              const SizedBox(width: 10),
                              Expanded(child: _StatTile('$confirmed', 'Confirmed', Icons.check_circle_rounded, AppColors.success)),
                            ]);
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 24),

                    // Quick actions
                    Row(children: [
                      _ActionTile(icon: Icons.people_rounded, label: 'Patients', color: AppColors.primary, onTap: () => context.go('/doc/patients')),
                      const SizedBox(width: 12),
                      _ActionTile(icon: Icons.calendar_month_rounded, label: 'Appointments', color: AppColors.doctorPrimary, onTap: () => context.go('/doc/appointments')),
                      const SizedBox(width: 12),
                      _ActionTile(icon: Icons.edit_note_rounded, label: 'Prescribe', color: AppColors.success, onTap: () => context.go('/doc/patients')),
                    ]),
                    const SizedBox(height: 28),

                    // Recent appointment requests
                    SectionHeader(title: 'Recent Requests', action: 'See all', onAction: () => context.go('/doc/appointments')),
                    const SizedBox(height: 12),
                    apptsAsync.when(
                      data: (appts) {
                        final pending = appts.where((a) => a.isPending).toList();
                        if (pending.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                            child: const Column(children: [
                              Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 36),
                              SizedBox(height: 10),
                              Text('All caught up', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                              SizedBox(height: 4),
                              Text('No pending appointment requests.', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                            ]),
                          );
                        }
                        return Column(
                          children: pending.take(5).map((a) => _PendingApptCard(appt: a)).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 20),
                  ])),
                ),
              ],
            ),
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

class _StatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatTile(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha:0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha:0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
          ]),
        ),
      ),
    );
  }
}

class _PendingApptCard extends ConsumerWidget {
  final Appointment appt;
  const _PendingApptCard({required this.appt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warningLight)),
      child: Row(children: [
        AppAvatar(name: appt.patientName, size: 40),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(appt.patientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          if (appt.patientNote != null && appt.patientNote!.isNotEmpty)
            Text(appt.patientNote!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        ])),
        StatusBadge.warning('Pending'),
      ]),
    );
  }
}
