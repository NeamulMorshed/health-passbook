import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/appointment.dart';

class DocAppointmentsScreen extends ConsumerStatefulWidget {
  const DocAppointmentsScreen({super.key});

  @override
  ConsumerState<DocAppointmentsScreen> createState() => _DocAppointmentsScreenState();
}

class _DocAppointmentsScreenState extends ConsumerState<DocAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  // Created once and kept stable — never recreated on stream updates.
  // Recreating DefaultTabController inside a StreamBuilder is what causes the black screen.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Appointment Management'), automaticallyImplyLeading: false),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: 'Pull to refresh or try again.'),
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (context.mounted) context.go('/user-select'); },
            );
            return const Center(child: SizedBox.shrink());
          }

          final apptsAsync = ref.watch(doctorAppointmentsProvider(user.uid));

          return apptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: 'Pull to refresh or try again.'),
            data: (appts) {
              if (appts.isEmpty) {
                return const EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No Appointments',
                  subtitle: 'Appointment requests from patients will appear here.',
                );
              }

              final pending   = appts.where((a) => a.isPending).toList();
              final confirmed = appts.where((a) => a.isConfirmed).toList();
              final past      = appts.where((a) => a.isCompleted || a.isCancelled).toList();

              // TabBar and TabBarView both reference _tabController which is stable.
              // Only the tab labels (counts) and list contents update on each stream emit.
              return Column(children: [
                Container(
                  color: AppColors.surface,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.doctorPrimary,
                    unselectedLabelColor: AppColors.mutedForeground,
                    indicatorColor: AppColors.doctorPrimary,
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Confirmed (${confirmed.length})'),
                      Tab(text: 'Past (${past.length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ApptList(appts: pending, emptyTitle: 'No pending requests', emptySubtitle: 'New appointment requests from patients will appear here.'),
                      _ApptList(appts: confirmed, emptyTitle: 'No upcoming appointments', emptySubtitle: 'Confirmed appointments will show here.'),
                      _ApptList(appts: past, emptyTitle: 'No past appointments', emptySubtitle: 'Completed and cancelled appointments will appear here.'),
                    ],
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class _ApptList extends StatelessWidget {
  final List<Appointment> appts;
  final String emptyTitle;
  final String emptySubtitle;
  const _ApptList({required this.appts, required this.emptyTitle, required this.emptySubtitle});

  @override
  Widget build(BuildContext context) {
    if (appts.isEmpty) {
      return EmptyState(
          icon: Icons.event_available_rounded,
          title: emptyTitle,
          subtitle: emptySubtitle);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: appts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _DocApptCard(appt: appts[i]),
    );
  }
}

class _DocApptCard extends ConsumerWidget {
  final Appointment appt;
  const _DocApptCard({required this.appt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appt.isPending ? AppColors.warningLight : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppAvatar(name: appt.patientName, size: 44),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appt.patientName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            Text('Requested ${DateFormat('MMM d, h:mm a').format(appt.createdAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ])),
          _buildBadge(),
        ]),
        if (appt.patientNote != null && appt.patientNote!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(8)),
            child: Text('"${appt.patientNote}"',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Inter', color: AppColors.foreground)),
          ),
        ],
        if (appt.scheduledAt != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.doctorPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.doctorPrimary),
              const SizedBox(width: 8),
              Text(DateFormat('EEEE, MMM d, y - h:mm a').format(appt.scheduledAt!),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.doctorPrimary, fontFamily: 'Inter')),
            ]),
          ),
        ],
        if (appt.isPending) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showConfirmSheet(context, ref),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Set Date & Confirm'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success, minimumSize: const Size(0, 42)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _confirmCancel(context, ref),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(42, 42),
                  foregroundColor: AppColors.destructive,
                  side: const BorderSide(color: AppColors.destructive)),
              child: const Icon(Icons.close_rounded, size: 18),
            ),
          ]),
        ],
        if (appt.isConfirmed) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmComplete(context, ref),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Mark Completed'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, minimumSize: const Size(0, 42)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildBadge() {
    if (appt.isPending)   return StatusBadge.warning('Pending');
    if (appt.isConfirmed) return StatusBadge.success('Confirmed');
    if (appt.isCompleted) return StatusBadge.info('Completed');
    return StatusBadge.danger('Cancelled');
  }

  void _showConfirmSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConfirmApptSheet(appt: appt),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cancel Appointment', style: TextStyle(fontFamily: 'Inter')),
        content: Text('Cancel ${appt.patientName}\'s appointment request?',
            style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(doctorAppointmentNotifierProvider.notifier).cancel(
                appt.id,
                patientId: appt.patientId,
                doctorId: appt.doctorId,
              );
              if (!context.mounted) return;
              final state = ref.read(doctorAppointmentNotifierProvider);
              if (state is AsyncError) {
                showAppSnack(context, 'Failed to cancel. Check your connection and try again.');
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmComplete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Mark Completed', style: TextStyle(fontFamily: 'Inter')),
        content: Text('Mark ${appt.patientName}\'s appointment as completed?',
            style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Not yet')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(doctorAppointmentNotifierProvider.notifier).complete(appt.id);
              if (!context.mounted) return;
              final state = ref.read(doctorAppointmentNotifierProvider);
              if (state is AsyncError) {
                showAppSnack(context, 'Failed to mark completed. Check your connection and try again.');
              }
            },
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmApptSheet extends ConsumerStatefulWidget {
  final Appointment appt;
  const _ConfirmApptSheet({required this.appt});
  @override
  ConsumerState<_ConfirmApptSheet> createState() => _ConfirmApptSheetState();
}

class _ConfirmApptSheetState extends ConsumerState<_ConfirmApptSheet> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  void _confirm() async {
    final dt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;

    setState(() => _isLoading = true);

    await ref.read(doctorAppointmentNotifierProvider.notifier).confirm(
      widget.appt.id,
      dt,
      patientId: widget.appt.patientId,
      doctorId: user.uid,
      doctorName: user.name,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    final state = ref.read(doctorAppointmentNotifierProvider);
    if (state is AsyncError) {
      showAppSnack(context, 'Failed to confirm. Check your connection and try again.');
      return;
    }

    Navigator.pop(context);
    showAppSnack(context, 'Appointment confirmed for ${widget.appt.patientName}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Confirm: ${widget.appt.patientName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (date != null) setState(() => _selectedDate = date);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.doctorPrimary),
                  const SizedBox(width: 10),
                  Text(DateFormat('EEEE, MMM d, y').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: _selectedTime);
                if (time != null) setState(() => _selectedTime = time);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded, size: 18, color: AppColors.doctorPrimary),
                  const SizedBox(width: 10),
                  Text(_selectedTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Doctor Notes (optional)',
                    hintText: 'Instructions for the patient...')),
            const SizedBox(height: 20),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    label: 'Confirm Appointment',
                    colors: [AppColors.success, const Color(0xFF15803D)],
                    onPressed: _confirm,
                  ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
