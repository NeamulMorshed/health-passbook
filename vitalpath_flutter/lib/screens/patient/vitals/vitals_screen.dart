import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vitals_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../models/vital_reading.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.',
        ),
      ),
      data: (user) {
        if (user == null) return const Scaffold(body: SizedBox.shrink());
        return _VitalsContent(patientId: user.uid);
      },
    );
  }
}

class _VitalsContent extends ConsumerWidget {
  final String patientId;
  const _VitalsContent({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsAsync = ref.watch(vitalsProvider(patientId));

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Vitals'),
        automaticallyImplyLeading: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogVitalSheet(context, ref, patientId),
        backgroundColor: AppColors.primary,
        icon: HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: Colors.white, size: 20),
        label: const Text('Log a Vital', style: TextStyle(color: Colors.white)),
      ),
      body: vitalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading vitals',
          subtitle: 'Check your connection and try again.',
        ),
        data: (readings) {
          final latestBpSys   = readings.where((r) => r.type == VitalType.bpSystolic).firstOrNull;
          final latestBpDia   = readings.where((r) => r.type == VitalType.bpDiastolic).firstOrNull;
          final latestPulse   = readings.where((r) => r.type == VitalType.pulse).firstOrNull;
          final latestSpo2    = readings.where((r) => r.type == VitalType.spo2).firstOrNull;
          final latestTemp    = readings.where((r) => r.type == VitalType.temp).firstOrNull;
          final latestGlucose = readings.where((r) => r.type == VitalType.glucose).firstOrNull;

          String fmt(VitalReading? r) {
            if (r == null) return '--';
            return r.value.truncateToDouble() == r.value
                ? r.value.toInt().toString()
                : r.value.toStringAsFixed(1);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VitalStatusCard(patientId: patientId, readings: readings),
                const SizedBox(height: 20),
                BentoSectionHeader(title: 'Current Readings'),
                const SizedBox(height: 12),
                BentoRow(
                  left: BentoStatCard(
                    label: 'Blood Pressure',
                    value: latestBpSys != null
                        ? '${latestBpSys.value.toInt()}/${latestBpDia?.value.toInt() ?? '-'}'
                        : '--',
                    unit: 'mmHg',
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedDroplet, color: const Color(0xFF3B82F6), size: 20),
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF3B82F6),
                    onTap: () => _showHistorySheet(context, VitalType.bpSystolic),
                  ),
                  right: BentoStatCard(
                    label: 'Heart Rate',
                    value: fmt(latestPulse),
                    unit: VitalType.unitFor(VitalType.pulse),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedActivity01, color: AppColors.destructive, size: 20),
                    iconBgColor: AppColors.destructiveLight,
                    iconColor: AppColors.destructive,
                    onTap: () => _showHistorySheet(context, VitalType.pulse),
                  ),
                ),
                const SizedBox(height: 12),
                BentoRow(
                  left: BentoStatCard(
                    label: 'SpO₂',
                    value: fmt(latestSpo2),
                    unit: VitalType.unitFor(VitalType.spo2),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedActivity01, color: AppColors.success, size: 20),
                    iconBgColor: AppColors.successLight,
                    iconColor: AppColors.success,
                    onTap: () => _showHistorySheet(context, VitalType.spo2),
                  ),
                  right: BentoStatCard(
                    label: 'Temperature',
                    value: fmt(latestTemp),
                    unit: VitalType.unitFor(VitalType.temp),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedTemperature, color: AppColors.warning, size: 20),
                    iconBgColor: AppColors.warningLight,
                    iconColor: AppColors.warning,
                    onTap: () => _showHistorySheet(context, VitalType.temp),
                  ),
                ),
                const SizedBox(height: 12),
                BentoStatCard(
                  label: 'Glucose',
                  value: fmt(latestGlucose),
                  unit: VitalType.unitFor(VitalType.glucose),
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedDroplet, color: AppColors.warning, size: 20),
                  iconBgColor: AppColors.warningLight,
                  iconColor: AppColors.warning,
                  onTap: () => _showHistorySheet(context, VitalType.glucose),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLogVitalSheet(BuildContext context, WidgetRef ref, String patientId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LogVitalSheet(patientId: patientId),
    );
  }

  void _showHistorySheet(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VitalHistorySheet(patientId: patientId, type: type),
    );
  }
}

// ─── Borderline helpers ───────────────────────────────────────────────────────
double _borderlineLow(String type, double min) {
  if (type == VitalType.temp) return min - 0.5;
  if (type == VitalType.bpSystolic || type == VitalType.bpDiastolic) return min - 5;
  if (type == VitalType.glucose) return min - 5;
  return min * 0.9;
}

double _borderlineHigh(String type, double max) {
  if (type == VitalType.temp) return max + 0.5;
  if (type == VitalType.bpSystolic || type == VitalType.bpDiastolic) return max + 5;
  if (type == VitalType.glucose) return max + 5;
  return max * 1.1;
}

// ─── Log Vital Sheet ──────────────────────────────────────────────────────────
class _LogVitalSheet extends ConsumerStatefulWidget {
  final String patientId;
  const _LogVitalSheet({required this.patientId});

  @override
  ConsumerState<_LogVitalSheet> createState() => _LogVitalSheetState();
}

class _LogVitalSheetState extends ConsumerState<_LogVitalSheet> {
  String _selectedType = VitalType.bpSystolic;
  final _valueCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  static (double, double) _physicalRange(String type) => switch (type) {
    VitalType.bpSystolic  => (50, 300),
    VitalType.bpDiastolic => (30, 200),
    VitalType.glucose     => (10, 600),
    VitalType.temp        => (30, 45),
    VitalType.spo2        => (50, 100),
    VitalType.pulse       => (20, 300),
    _                     => (0, double.infinity),
  };

  void _save() async {
    final val = double.tryParse(_valueCtrl.text.trim());
    if (val == null || val <= 0) {
      showAppSnack(context, 'Please enter a valid positive number.', isError: true);
      return;
    }
    final (minP, maxP) = _physicalRange(_selectedType);
    if (val < minP || val > maxP) {
      showAppSnack(
        context,
        'Value is outside the physically possible range for ${VitalType.labelFor(_selectedType)} ($minP–$maxP ${VitalType.unitFor(_selectedType)}).',
        isError: true,
      );
      return;
    }

    // Soft confirmation for readings outside the normal (clinically healthy) range.
    if (!VitalType.isNormal(_selectedType, val)) {
      final (minN, maxN) = VitalType.normalRange(_selectedType);
      final unit = VitalType.unitFor(_selectedType);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unusual Reading', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Text(
            '${VitalType.labelFor(_selectedType)} of $val $unit is outside the normal range ($minN–$maxN $unit). '
            'Please double-check the value. Log anyway?',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Log Anyway'),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      setState(() => _saving = true);
      await ref.read(vitalsNotifierProvider.notifier).add(
            patientId: widget.patientId,
            type: _selectedType,
            value: val,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, '${VitalType.labelFor(_selectedType)} logged.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save reading. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _hasInput => _valueCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Discard reading?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) Navigator.pop(context);
      },
      child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Log a Vital',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              // Type selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: VitalType.allTypes.map((type) {
                  final sel = _selectedType == type;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedType = type;
                      _valueCtrl.clear();
                    }),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        VitalType.labelFor(type),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      '${VitalType.labelFor(_selectedType)} (${VitalType.unitFor(_selectedType)})',
                  hintText: 'Enter value',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Taken after rest',
                ),
              ),
              const SizedBox(height: 20),

              GradientButton(
                label: _saving ? 'Saving...' : 'Save Reading',
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    )); // closes PopScope child Padding
  }
}

// ─── Vital History Sheet ──────────────────────────────────────────────────────
class _VitalHistorySheet extends ConsumerWidget {
  final String patientId;
  final String type;
  const _VitalHistorySheet({required this.patientId, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allReadings = ref.watch(vitalsProvider(patientId)).asData?.value ?? [];
    final readings = allReadings.where((r) => r.type == type).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    VitalType.labelFor(type),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Unit: ${VitalType.unitFor(type)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                ],
              ),
            ),
            Expanded(
              child: readings.isEmpty
                  ? Center(
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
                              child: HugeIcon(icon: HugeIcons.strokeRoundedActivity01, color: AppColors.mutedForeground, size: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text('No Readings Yet',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            const Text(
                              'Log your first reading using the button below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: readings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = readings[i];
                        final isNormal = VitalType.isNormal(type, r.value);
                        final (min, max) = VitalType.normalRange(type);
                        final val = r.value;
                        final borderlineLow = _borderlineLow(type, min);
                        final borderlineHigh = _borderlineHigh(type, max);

                        final Color statusColor;
                        final Widget statusIcon;
                        if (isNormal) {
                          statusColor = AppColors.success;
                          statusIcon = HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: AppColors.success, size: 16);
                        } else if (val >= borderlineLow && val <= borderlineHigh) {
                          statusColor = AppColors.warning;
                          statusIcon = HugeIcon(icon: HugeIcons.strokeRoundedAlertDiamond, color: AppColors.warning, size: 16);
                        } else {
                          statusColor = AppColors.destructive;
                          statusIcon = Icon(Icons.error_rounded, size: 16, color: AppColors.destructive);
                        }

                        return BentoCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            statusIcon,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.value.truncateToDouble() == r.value ? r.value.toInt() : r.value.toStringAsFixed(1)} ${r.unit}',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor),
                                  ),
                                  Text(
                                    DateFormat('MMM d, h:mm a').format(r.recordedAt),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedForeground),
                                  ),
                                  if (r.note != null && r.note!.isNotEmpty)
                                    Text(
                                      r.note!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedForeground),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: AppColors.mutedForeground,
                              tooltip: 'Delete reading',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('Delete Reading?',
                                        style: TextStyle(fontWeight: FontWeight.w600)),
                                    content: const Text('This reading will be permanently deleted.'),
                                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    actions: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.destructive),
                                            onPressed: () => Navigator.pop(dialogCtx, true),
                                            child: const Text('Delete'),
                                          ),
                                          const SizedBox(height: 4),
                                          Center(
                                            child: TextButton(
                                              onPressed: () => Navigator.pop(dialogCtx, false),
                                              child: const Text('Cancel'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  try {
                                    await ref
                                        .read(vitalsNotifierProvider.notifier)
                                        .delete(r.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text('Failed to delete reading. Please try again.'),
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    }
                                  }
                                }
                              },
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vital Status Card ─────────────────────────────────────────────────────────
class _VitalStatusCard extends ConsumerWidget {
  final String patientId;
  final List<VitalReading> readings;
  const _VitalStatusCard({required this.patientId, required this.readings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicinesProvider(patientId)).asData?.value ?? [];
    final gamProfile = ref.watch(gamificationProvider(patientId)).asData?.value;

    final activeMeds = meds.where((m) => m.isActive).toList();
    final missedMeds = activeMeds.where((m) => m.hasMissedSlot && !m.hasDueSlot).toList();
    final abnormalReadings = readings.where((r) => !VitalType.isNormal(r.type, r.value)).toList();

    final Color statusColor;
    final String statusText;
    final Widget statusIcon;

    if (missedMeds.isNotEmpty && abnormalReadings.isNotEmpty) {
      statusColor = AppColors.destructive;
      statusText = 'Needs attention';
      statusIcon = HugeIcon(icon: HugeIcons.strokeRoundedAlertDiamond, color: AppColors.destructive, size: 13);
    } else if (missedMeds.isNotEmpty || abnormalReadings.isNotEmpty) {
      statusColor = AppColors.warning;
      statusText = 'Check in today';
      statusIcon = HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: AppColors.warning, size: 13);
    } else if (activeMeds.isNotEmpty && activeMeds.every((m) => m.takenToday)) {
      statusColor = AppColors.success;
      statusText = 'On track';
      statusIcon = HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: AppColors.success, size: 13);
    } else {
      statusColor = AppColors.primary;
      statusText = 'Good day';
      statusIcon = HugeIcon(icon: HugeIcons.strokeRoundedSun01, color: AppColors.primary, size: 13);
    }

    final medStreak = gamProfile?.medStreak ?? 0;
    final latestBpSys = readings.where((r) => r.type == VitalType.bpSystolic).firstOrNull;
    final latestBpDia = readings.where((r) => r.type == VitalType.bpDiastolic).firstOrNull;
    final latestPulse = readings.where((r) => r.type == VitalType.pulse).firstOrNull;
    final latestGlucose = readings.where((r) => r.type == VitalType.glucose).firstOrNull;
    final vitalSummary = _interpret(latestBpSys, latestBpDia, latestPulse, latestGlucose);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withValues(alpha: 0.08), statusColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              statusIcon,
              const SizedBox(width: 5),
              Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
            ]),
          ),
          const Spacer(),
          if (medStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.caregiver.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department_rounded, size: 13, color: AppColors.caregiver),
                const SizedBox(width: 4),
                Text('$medStreak day streak', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.caregiver)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        Text(vitalSummary, style: const TextStyle(fontSize: 13, color: AppColors.foreground, height: 1.4)),
        if (latestBpSys != null || latestPulse != null || latestGlucose != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (latestBpSys != null && latestBpDia != null)
              _VitalChip(
                label: '${latestBpSys.value.toInt()}/${latestBpDia.value.toInt()}',
                unit: 'mmHg',
                iconBuilder: (c) => HugeIcon(icon: HugeIcons.strokeRoundedHeartCheck, color: c, size: 12),
                isNormal: VitalType.isNormal(VitalType.bpSystolic, latestBpSys.value) &&
                    VitalType.isNormal(VitalType.bpDiastolic, latestBpDia.value),
              ),
            if (latestPulse != null)
              _VitalChip(
                label: '${latestPulse.value.toInt()}',
                unit: 'bpm',
                iconBuilder: (c) => HugeIcon(icon: HugeIcons.strokeRoundedChartIncrease, color: c, size: 12),
                isNormal: VitalType.isNormal(VitalType.pulse, latestPulse.value),
              ),
            if (latestGlucose != null)
              _VitalChip(
                label: '${latestGlucose.value.toInt()}',
                unit: 'mg/dL',
                iconBuilder: (c) => HugeIcon(icon: HugeIcons.strokeRoundedDroplet, color: c, size: 12),
                isNormal: VitalType.isNormal(VitalType.glucose, latestGlucose.value),
              ),
          ]),
        ],
      ]),
    );
  }

  String _interpret(VitalReading? bpSys, VitalReading? bpDia, VitalReading? pulse, VitalReading? glucose) {
    if (bpSys == null && pulse == null && glucose == null) return 'No vitals logged yet — use the button below to add your first reading.';
    final parts = <String>[];
    if (bpSys != null && bpDia != null) {
      final ok = VitalType.isNormal(VitalType.bpSystolic, bpSys.value) && VitalType.isNormal(VitalType.bpDiastolic, bpDia.value);
      parts.add(ok
          ? 'Blood pressure is within normal range (${bpSys.value.toInt()}/${bpDia.value.toInt()} mmHg)'
          : bpSys.value > 120
              ? 'Blood pressure is slightly elevated (${bpSys.value.toInt()}/${bpDia.value.toInt()} mmHg)'
              : 'Blood pressure is low (${bpSys.value.toInt()}/${bpDia.value.toInt()} mmHg)');
    }
    if (glucose != null && !VitalType.isNormal(VitalType.glucose, glucose.value)) {
      parts.add('glucose is ${glucose.value > 140 ? "above target" : "low"} (${glucose.value.toInt()} mg/dL)');
    }
    if (pulse != null && !VitalType.isNormal(VitalType.pulse, pulse.value)) {
      parts.add('pulse is ${pulse.value > 100 ? "elevated" : "low"} (${pulse.value.toInt()} bpm)');
    }
    if (parts.isEmpty) return 'Vitals are looking good — keep it up!';
    final first = parts.first[0].toUpperCase() + parts.first.substring(1);
    return parts.length > 1 ? '$first and ${parts.sublist(1).join(', ')}.' : '$first.';
  }
}

// ── Vital Chip ────────────────────────────────────────────────────────────────
class _VitalChip extends StatelessWidget {
  final String label, unit;
  final Widget Function(Color color) iconBuilder;
  final bool isNormal;
  const _VitalChip({required this.label, required this.unit, required this.iconBuilder, required this.isNormal});

  @override
  Widget build(BuildContext context) {
    final color = isNormal ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        iconBuilder(color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 3),
        Text(unit, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        const SizedBox(width: 5),
        isNormal
            ? HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: color, size: 11)
            : HugeIcon(icon: HugeIcons.strokeRoundedAlertDiamond, color: color, size: 11),
      ]),
    );
  }
}
