import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../models/caregiver_connection.dart';
import '../../../providers/caregiver_provider.dart';

final _db = FirebaseFirestore.instance;

class ManageCaregiverScreen extends ConsumerStatefulWidget {
  final CaregiverConnection connection;
  const ManageCaregiverScreen({super.key, required this.connection});

  @override
  ConsumerState<ManageCaregiverScreen> createState() =>
      _ManageCaregiverScreenState();
}

class _ManageCaregiverScreenState
    extends ConsumerState<ManageCaregiverScreen> {
  late CaregiverPermissions _permissions;
  late CaregiverNotifSettings _notifSettings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _permissions = widget.connection.permissions;
    _notifSettings = widget.connection.notifSettings;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // C-MC3: single atomic Firestore update instead of two separate calls
      await _db
          .collection('caregiver_connections')
          .doc(widget.connection.id)
          .update({
        'permissions': _permissions.toMap(),
        'notifSettings': _notifSettings.toMap(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmRemove() async {
    // C-MC1: use dialogCtx so Navigator.pop closes the dialog, not the screen
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
            'Remove ${widget.connection.caregiverName ?? widget.connection.caregiverEmail}?'),
        content: const Text(
            'They will immediately lose access to your health data and stop receiving notifications.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
                  child: const Text('Yes, Remove')),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: const Text('Cancel')),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref
            .read(caregiverConnectionNotifierProvider.notifier)
            .remove(widget.connection.id);
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to remove caregiver. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.connection.caregiverName ??
        widget.connection.caregiverEmail;
    // M-MC1: prevent navigation while saving
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _saving) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please wait, saving changes...')));
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text('${name.split(' ').first}\'s Access'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
                onPressed: _save,
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Permissions ──────────────────────────────────────────────────
          _SectionTitle('What ${name.split(' ').first} can see'),
          const SizedBox(height: 10),

          _PermSwitch(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.mutedForeground, size: 20),
            label: 'Medicines & dose tracking',
            value: _permissions.medicines,
            onChanged: (v) =>
                setState(() => _permissions = _permissions.copyWith(medicines: v)),
          ),
          _PermSwitch(
            icon: const Icon(Icons.monitor_heart_rounded, size: 20, color: AppColors.mutedForeground),
            label: 'Vitals & readings',
            value: _permissions.vitals,
            onChanged: (v) =>
                setState(() => _permissions = _permissions.copyWith(vitals: v)),
          ),
          _PermSwitch(
            icon: const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.mutedForeground),
            label: 'Upcoming appointments',
            value: _permissions.appointments,
            onChanged: (v) =>
                setState(() => _permissions = _permissions.copyWith(appointments: v)),
          ),
          _PermSwitch(
            icon: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.mutedForeground),
            label: 'Prescriptions',
            value: _permissions.prescriptions,
            onChanged: (v) =>
                setState(() => _permissions = _permissions.copyWith(prescriptions: v)),
          ),
          _PermSwitch(
            icon: const Icon(Icons.restaurant_rounded, size: 20, color: AppColors.mutedForeground),
            label: 'Meal logs',
            value: _permissions.mealLogs,
            onChanged: (v) =>
                setState(() => _permissions = _permissions.copyWith(mealLogs: v)),
          ),
          _PermSwitch(
            icon: const Icon(Icons.directions_run_rounded, size: 20, color: AppColors.mutedForeground),
            label: 'Activity logs',
            value: _permissions.activityLogs,
            onChanged: (v) =>
                setState(() => _permissions = _permissions.copyWith(activityLogs: v)),
          ),

          const SizedBox(height: 28),

          // ── Notifications ────────────────────────────────────────────────
          _SectionTitle('Notifications'),
          const SizedBox(height: 10),

          _NotifGroup(
            title: 'Medicines',
            children: [
              _NotifSwitch(
                label: 'Missed dose alerts',
                value: _notifSettings.missedDose,
                onChanged: (v) => setState(
                    () => _notifSettings = _notifSettings.copyWith(missedDose: v)),
              ),
              _NotifSwitch(
                label: 'Medicine added by doctor',
                value: _notifSettings.newPrescription,
                onChanged: (v) => setState(() =>
                    _notifSettings =
                        _notifSettings.copyWith(newPrescription: v)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _NotifGroup(
            title: 'Vitals',
            children: [
              _NotifSwitch(
                label: 'Abnormal reading detected',
                value: _notifSettings.abnormalVital,
                onChanged: (v) => setState(() =>
                    _notifSettings =
                        _notifSettings.copyWith(abnormalVital: v)),
              ),
              if (_notifSettings.abnormalVital) ...[
                const SizedBox(height: 8),
                _ThresholdRow(
                  label: 'Blood pressure systolic >',
                  value: _notifSettings.bpSystolicThreshold,
                  unit: 'mmHg',
                  onTap: () => _editThreshold(
                    label: 'BP Systolic threshold',
                    unit: 'mmHg',
                    current: _notifSettings.bpSystolicThreshold,
                    onSave: (v) => setState(() => _notifSettings =
                        _notifSettings.copyWith(bpSystolicThreshold: v)),
                  ),
                ),
                _ThresholdRow(
                  label: 'Blood glucose >',
                  value: _notifSettings.glucoseThreshold,
                  unit: 'mg/dL',
                  onTap: () => _editThreshold(
                    label: 'Blood glucose threshold',
                    unit: 'mg/dL',
                    current: _notifSettings.glucoseThreshold,
                    onSave: (v) => setState(() => _notifSettings =
                        _notifSettings.copyWith(glucoseThreshold: v)),
                  ),
                ),
                // H-MC1: implement heart rate range tap
                _ThresholdRow(
                  label: 'Heart rate outside',
                  value: null,
                  unit:
                      '${_notifSettings.heartRateMin.toInt()}–${_notifSettings.heartRateMax.toInt()} bpm',
                  onTap: () => _pickThresholdRange(
                    label: 'Heart rate range (bpm)',
                    minLabel: 'Min BPM',
                    maxLabel: 'Max BPM',
                    currentMin: _notifSettings.heartRateMin,
                    currentMax: _notifSettings.heartRateMax,
                    onSave: (min, max) => setState(() => _notifSettings =
                        _notifSettings.copyWith(
                            heartRateMin: min, heartRateMax: max)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          _NotifGroup(
            title: 'Appointments',
            children: [
              _NotifSwitch(
                label: 'Upcoming appointment reminder',
                value: _notifSettings.upcomingAppointment,
                onChanged: (v) => setState(() =>
                    _notifSettings =
                        _notifSettings.copyWith(upcomingAppointment: v)),
              ),
              _NotifSwitch(
                label: 'Appointment confirmed / cancelled',
                value: _notifSettings.appointmentStatusChange,
                onChanged: (v) => setState(() =>
                    _notifSettings = _notifSettings.copyWith(
                        appointmentStatusChange: v)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _NotifGroup(
            title: 'General',
            children: [
              _NotifSwitch(
                label: 'Weekly health summary',
                value: _notifSettings.weeklySummary,
                onChanged: (v) => setState(() =>
                    _notifSettings =
                        _notifSettings.copyWith(weeklySummary: v)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Quiet hours ──────────────────────────────────────────────────
          _NotifGroup(
            title: 'Quiet Hours',
            children: [
              if (_notifSettings.quietHoursStart != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${_notifSettings.quietHoursStart} – ${_notifSettings.quietHoursEnd}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() =>
                          _notifSettings = _notifSettings.copyWith(
                              clearQuietHours: true)),
                      child: const Text('Remove',
                          style: TextStyle(color: AppColors.destructive)),
                    ),
                  ]),
                )
              else
                TextButton.icon(
                  onPressed: _pickQuietHours,
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedMoon, color: Colors.black, size: 18),
                  label: const Text('Set quiet hours'),
                ),
            ],
          ),

          const SizedBox(height: 36),

          // ── Remove ───────────────────────────────────────────────────────
          OutlinedButton(
            onPressed: _confirmRemove,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.destructive,
              side: const BorderSide(color: AppColors.destructive),
            ),
            child: Text('Remove ${name.split(' ').first} from Health Circle'),
          ),

          const SizedBox(height: 24),
        ],
      ),
      ), // close Scaffold
    ); // close PopScope
  }

  Future<void> _editThreshold({
    required String label,
    required String unit,
    required double current,
    required ValueChanged<double> onSave,
  }) async {
    final ctrl = TextEditingController(text: current.toInt().toString());
    // C-MC2: use dialogCtx so Navigator.pop closes the dialog, not the screen
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: unit),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Save')),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: const Text('Cancel')),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctrl.text);
      if (v != null) onSave(v);
    }
  }

  Future<void> _pickQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Quiet hours start',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Quiet hours end',
    );
    if (end == null || !mounted) return;

    // H-MC2: warn when end <= start (cross-midnight), but don't block it
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Quiet hours span midnight'),
          content: Text(
              'Quiet hours from ${start.format(context)} to ${end.format(context)} '
              'will span midnight (e.g., 22:00–07:00). Is that correct?'),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    child: const Text('Confirm')),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Change')),
                ),
              ],
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _notifSettings = _notifSettings.copyWith(
        quietHoursStart: start.format(context),
        quietHoursEnd: end.format(context),
      );
    });
  }

  /// H-MC1: dialog to pick a min/max range (used for heart rate)
  Future<void> _pickThresholdRange({
    required String label,
    required String minLabel,
    required String maxLabel,
    required double currentMin,
    required double currentMax,
    required void Function(double min, double max) onSave,
  }) async {
    final minCtrl = TextEditingController(text: currentMin.toInt().toString());
    final maxCtrl = TextEditingController(text: currentMax.toInt().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: minLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: maxLabel),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Save')),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: const Text('Cancel')),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok == true) {
      final min = double.tryParse(minCtrl.text);
      final max = double.tryParse(maxCtrl.text);
      if (min != null && max != null) onSave(min, max);
    }
    minCtrl.dispose();
    maxCtrl.dispose();
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700));
}

class _PermSwitch extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoCard(
        padding: EdgeInsets.zero,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          secondary: icon,
          title: Text(label, style: const TextStyle(fontSize: 14)),
          activeThumbColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          dense: true,
        ),
      ),
    );
  }
}

class _NotifGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _NotifGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                    letterSpacing: 0.5)),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NotifSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifSwitch(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      activeThumbColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      dense: true,
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final VoidCallback? onTap;

  const _ThresholdRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value != null ? '${value!.toInt()} $unit' : unit,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary),
            ),
          ),
        ),
      ]),
    );
  }
}
