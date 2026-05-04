import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vitals_provider.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vitals'),
        automaticallyImplyLeading: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogVitalSheet(context, ref, patientId),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Log a Vital',
            style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
      ),
      body: vitalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading vitals',
          subtitle: 'Check your connection and try again.',
        ),
        data: (readings) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Current Readings'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: VitalType.allTypes.map((type) {
                    final latest = readings.where((r) => r.type == type).firstOrNull;
                    return _VitalTypeCard(
                      type: type,
                      latest: latest,
                      onTap: () => _showHistorySheet(context, type, readings),
                    );
                  }).toList(),
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

  void _showHistorySheet(
      BuildContext context, String type, List<VitalReading> allReadings) {
    final readings = allReadings.where((r) => r.type == type).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VitalHistorySheet(type: type, readings: readings),
    );
  }
}

// ─── Vital Type Card ──────────────────────────────────────────────────────────
class _VitalTypeCard extends StatelessWidget {
  final String type;
  final VitalReading? latest;
  final VoidCallback onTap;

  const _VitalTypeCard({
    required this.type,
    required this.latest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNormal = latest != null && VitalType.isNormal(type, latest!.value);
    final hasReading = latest != null;

    Color dotColor;
    if (!hasReading) {
      dotColor = AppColors.mutedForeground;
    } else if (isNormal) {
      dotColor = AppColors.success;
    } else {
      final (min, max) = VitalType.normalRange(type);
      final val = latest!.value;
      // borderline: within 10% outside range
      final borderlineLow = min * 0.9;
      final borderlineHigh = max * 1.1;
      dotColor = (val >= borderlineLow && val <= borderlineHigh)
          ? AppColors.warning
          : AppColors.destructive;
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    VitalType.labelFor(type),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ]),
              const Spacer(),
              if (hasReading) ...[
                Text(
                  latest!.value % 1 == 0
                      ? latest!.value.toInt().toString()
                      : latest!.value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: dotColor == AppColors.mutedForeground
                        ? AppColors.foreground
                        : dotColor,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  VitalType.unitFor(type),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter',
                  ),
                ),
              ] else ...[
                const Text(
                  '--',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter',
                  ),
                ),
                const Text(
                  'No readings yet',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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

  void _save() async {
    final val = double.tryParse(_valueCtrl.text.trim());
    if (val == null) {
      showAppSnack(context, 'Please enter a valid number.', isError: true);
      return;
    }
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
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
                          fontFamily: 'Inter',
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
    );
  }
}

// ─── Vital History Sheet ──────────────────────────────────────────────────────
class _VitalHistorySheet extends StatelessWidget {
  final String type;
  final List<VitalReading> readings;
  const _VitalHistorySheet({required this.type, required this.readings});

  @override
  Widget build(BuildContext context) {
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                  ),
                  Text(
                    'Unit: ${VitalType.unitFor(type)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                ],
              ),
            ),
            Expanded(
              child: readings.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.monitor_heart_outlined,
                        title: 'No Readings Yet',
                        subtitle: 'Log your first reading using the button below.',
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
                        final borderlineLow = min * 0.9;
                        final borderlineHigh = max * 1.1;

                        Color statusColor;
                        IconData statusIcon;
                        if (isNormal) {
                          statusColor = AppColors.success;
                          statusIcon = Icons.check_circle_rounded;
                        } else if (val >= borderlineLow && val <= borderlineHigh) {
                          statusColor = AppColors.warning;
                          statusIcon = Icons.warning_amber_rounded;
                        } else {
                          statusColor = AppColors.destructive;
                          statusIcon = Icons.error_rounded;
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            Icon(statusIcon, size: 16, color: statusColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.value % 1 == 0 ? r.value.toInt() : r.value.toStringAsFixed(1)} ${r.unit}',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                        fontFamily: 'Inter'),
                                  ),
                                  Text(
                                    DateFormat('MMM d, h:mm a').format(r.recordedAt),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.mutedForeground,
                                        fontFamily: 'Inter'),
                                  ),
                                  if (r.note != null && r.note!.isNotEmpty)
                                    Text(
                                      r.note!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mutedForeground,
                                          fontFamily: 'Inter'),
                                    ),
                                ],
                              ),
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
