import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/appointment.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Appointments')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) {
          if (user == null) return const Center(child: CircularProgressIndicator());
          final apptsAsync = ref.watch(patientAppointmentsProvider(user.uid));

          return apptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (appts) {
              if (appts.isEmpty) {
                return const EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No Appointments',
                  subtitle: 'Book an appointment with a doctor from the My Doctors page.',
                );
              }
              final pending = appts.where((a) => a.isPending).toList();
              final confirmed = appts.where((a) => a.isConfirmed).toList();
              final past = appts.where((a) => a.isCompleted || a.isCancelled).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pending.isNotEmpty) ...[
                    const SectionHeader(title: 'Pending'),
                    const SizedBox(height: 10),
                    ...pending.map((a) => _ApptCard(appt: a)),
                    const SizedBox(height: 20),
                  ],
                  if (confirmed.isNotEmpty) ...[
                    const SectionHeader(title: 'Confirmed'),
                    const SizedBox(height: 10),
                    ...confirmed.map((a) => _ApptCard(appt: a)),
                    const SizedBox(height: 20),
                  ],
                  if (past.isNotEmpty) ...[
                    const SectionHeader(title: 'Past'),
                    const SizedBox(height: 10),
                    ...past.map((a) => _ApptCard(appt: a)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ApptCard extends StatelessWidget {
  final Appointment appt;
  const _ApptCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    StatusBadge badge;
    if (appt.isPending) {
      badge = StatusBadge.warning('Pending');
    } else if (appt.isConfirmed) {
      badge = StatusBadge.success('Confirmed');
    } else if (appt.isCompleted) {
      badge = StatusBadge.info('Completed');
    } else {
      badge = StatusBadge.danger('Cancelled');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AppAvatar(name: appt.doctorName, size: 40, backgroundColor: AppColors.doctorPrimary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dr. ${appt.doctorName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              if (appt.doctorSpecialty \!= null)
                Text(appt.doctorSpecialty\!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ])),
            badge,
          ]),
          if (appt.scheduledAt \!= null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMM d, y - h:mm a').format(appt.scheduledAt\!),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Inter'),
                ),
              ]),
            ),
          ],
          if (appt.patientNote \!= null && appt.patientNote\!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Your note: ${appt.patientNote}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontStyle: FontStyle.italic, fontFamily: 'Inter')),
          ],
          if (appt.notes \!= null && appt.notes\!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Doctor note: ${appt.notes}', style: const TextStyle(fontSize: 12, color: AppColors.foreground, fontFamily: 'Inter')),
          ],
        ],
      ),
    );
  }
}
