import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/appointment.dart';

// Tracks how many appointments to load. Incrementing triggers a new query.
final _apptLimitProvider = StateProvider.autoDispose<int>((ref) => 20);
const _pageSize = 20;

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('My Appointments'),
        automaticallyImplyLeading: false,
        actions: const [NotifBell()],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
            icon: Icons.wifi_off_rounded,
            title: "Can't load appointments",
            subtitle: 'Check your connection and pull to refresh.'),
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) {
                if (context.mounted) context.go('/user-select');
              },
            );
            return const Center(child: SizedBox.shrink());
          }

          final limit = ref.watch(_apptLimitProvider);
          final apptsAsync = ref.watch(patientAppointmentsProvider(
              (patientId: user.uid, limit: limit + 1)));

          return apptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(
                icon: Icons.wifi_off_rounded,
                title: "Can't load appointments",
                subtitle: 'Check your connection and pull to refresh.'),
            data: (rawAppts) {
              final hasMore = rawAppts.length > limit;
              final appts = hasMore ? rawAppts.take(limit).toList() : rawAppts;

              if (appts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar01,
                              color: AppColors.mutedForeground,
                              size: 48),
                        ),
                        const SizedBox(height: 16),
                        const Text('No Appointments',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                          'Book an appointment with a doctor from the My Doctors page.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final pending = appts.where((a) => a.isPending).toList();
              final confirmed = appts.where((a) => a.isConfirmed).toList();
              final past =
                  appts.where((a) => a.isCompleted || a.isCancelled).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  if (pending.isNotEmpty) ...[
                    BentoSectionHeader(title: 'Awaiting Confirmation'),
                    const SizedBox(height: 10),
                    ...pending.map((a) => _ApptCard(appt: a)),
                    const SizedBox(height: 20),
                  ],
                  if (confirmed.isNotEmpty) ...[
                    BentoSectionHeader(title: 'Confirmed'),
                    const SizedBox(height: 10),
                    ...confirmed.map((a) => _ApptCard(appt: a)),
                    const SizedBox(height: 20),
                  ],
                  if (past.isNotEmpty) ...[
                    BentoSectionHeader(title: 'Past'),
                    const SizedBox(height: 10),
                    ...past.map((a) => _ApptCard(appt: a)),
                    const SizedBox(height: 12),
                  ],
                  if (hasMore)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(_apptLimitProvider.notifier)
                          .state += _pageSize,
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          color: AppColors.primary,
                          size: 24),
                      label: const Text('Load more'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Showing all ${appts.length} appointment${appts.length == 1 ? '' : 's'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mutedForeground),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ApptCard extends ConsumerWidget {
  final Appointment appt;
  const _ApptCard({required this.appt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    StatusBadge badge;
    if (appt.isPending) {
      badge = StatusBadge.warning('Awaiting Confirmation');
    } else if (appt.isConfirmed) {
      badge = StatusBadge.success('Confirmed');
    } else if (appt.isCompleted) {
      badge = StatusBadge.info('Completed');
    } else {
      badge = StatusBadge.danger('Cancelled');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AppAvatar(
                  name: appt.doctorName,
                  size: 40,
                  backgroundColor: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Dr. ${appt.doctorName}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (appt.doctorSpecialty != null)
                      Text(appt.doctorSpecialty!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.mutedForeground)),
                  ])),
              badge,
            ]),
            if (appt.scheduledAt != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedClock01,
                      color: AppColors.primary,
                      size: 16),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, MMM d, y - h:mm a')
                        .format(appt.scheduledAt!),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ]),
              ),
            ],
            if (appt.patientNote != null && appt.patientNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Your note: ${appt.patientNote}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                      fontStyle: FontStyle.italic)),
            ],
            if (appt.notes != null && appt.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Doctor note: ${appt.notes}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.foreground)),
            ],
            if (appt.isPending) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, ref),
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancelCircle,
                    color: AppColors.destructive,
                    size: 16),
                label: const Text('Cancel Request'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  foregroundColor: AppColors.destructive,
                  side: const BorderSide(color: AppColors.destructive),
                ),
              ),
            ],
            if (appt.isConfirmed &&
                appt.scheduledAt != null &&
                appt.scheduledAt!.difference(DateTime.now()).inHours > 24) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, ref),
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancelCircle,
                    color: AppColors.destructive,
                    size: 16),
                label: const Text('Cancel Appointment'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  foregroundColor: AppColors.destructive,
                  side: const BorderSide(color: AppColors.destructive),
                ),
              ),
            ],
            // 7a: Messaging available once the appointment is confirmed
            // (and through completion). Hidden for pending/cancelled.
            if (appt.isConfirmed || appt.isCompleted) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/appointment-messages',
                    extra: appt),
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMessage01,
                    color: AppColors.primary,
                    size: 16),
                label: Text('Message ${appt.doctorName.split(' ').first}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
            if (appt.isCompleted) ...[
              const SizedBox(height: 12),
              appt.patientRating != null
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ...List.generate(
                          5,
                          (i) => Icon(
                                i < appt.patientRating!
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 18,
                                color: AppColors.warning,
                              )),
                      const SizedBox(width: 8),
                      const Text('Your rating',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.mutedForeground)),
                    ])
                  : OutlinedButton.icon(
                      onPressed: () => _showRateSheet(context),
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedStar,
                          color: AppColors.warning,
                          size: 16),
                      label: const Text('Rate this appointment'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RateAppointmentSheet(appt: appt),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    final isConfirmed = appt.isConfirmed;
    final title = isConfirmed ? 'Cancel Appointment' : 'Cancel Request';
    final content = isConfirmed
        ? 'Are you sure you want to cancel this confirmed appointment?'
        : 'Are you sure you want to cancel this appointment request?';
    final btnLabel = isConfirmed ? 'Cancel Appointment' : 'Cancel Request';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  await ref.read(appointmentNotifierProvider.notifier).cancel(
                        appt.id,
                        patientId: appt.patientId,
                        doctorId: appt.doctorId,
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop(); // dismiss loading dialog
                    showAppSnack(
                        context,
                        isConfirmed
                            ? 'Appointment cancelled.'
                            : 'Appointment request cancelled.');
                  }
                },
                child: Text(btnLabel),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Keep'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Rate Appointment Sheet ────────────────────────────────────────────────────
class _RateAppointmentSheet extends ConsumerStatefulWidget {
  final Appointment appt;
  const _RateAppointmentSheet({required this.appt});
  @override
  ConsumerState<_RateAppointmentSheet> createState() =>
      _RateAppointmentSheetState();
}

class _RateAppointmentSheetState extends ConsumerState<_RateAppointmentSheet> {
  int _rating = 0;
  bool _submitting = false;

  void _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    await ref.read(ratingNotifierProvider.notifier).submit(
          appointmentId: widget.appt.id,
          doctorId: widget.appt.doctorId,
          rating: _rating,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    final state = ref.read(ratingNotifierProvider);
    if (state is AsyncError) {
      showAppSnack(context, 'Failed to submit rating. Try again.');
      return;
    }
    Navigator.pop(context);
    showAppSnack(context, 'Rating submitted! Thank you.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Rate Dr. ${widget.appt.doctorName}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('How was your appointment experience?',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
            const SizedBox(height: 24),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        _rating >= star
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: AppColors.warning,
                      ),
                    ),
                  );
                })),
            const SizedBox(height: 8),
            Text(
              _rating == 0
                  ? 'Tap to rate'
                  : [
                      '',
                      'Poor',
                      'Fair',
                      'Good',
                      'Very Good',
                      'Excellent'
                    ][_rating],
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _rating == 0
                      ? AppColors.mutedForeground
                      : AppColors.warning),
            ),
            const SizedBox(height: 24),
            _submitting
                ? const CircularProgressIndicator()
                : GradientButton(
                    label: 'Submit Rating',
                    colors: [AppColors.warning, const Color(0xFFB45309)],
                    onPressed: _rating > 0 ? _submit : null,
                  ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
