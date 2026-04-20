import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/medication_entity.dart';
import '../providers/medication_provider.dart';
import 'duplicate_dose_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vertical Timeline — §7 SRS specification
// States: completed · in-progress · upcoming · overdue
// ─────────────────────────────────────────────────────────────────────────────

class TimelineWidget extends ConsumerWidget {
  const TimelineWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(todayMedicationsProvider);
    final logState  = ref.watch(medicationLogStateProvider);

    return medsAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => _buildError(e),
      data: (meds) {
        if (meds.isEmpty) return _buildEmpty();

        // Group by hour
        final groups = <String, List<MedicationEntity>>{};
        for (final med in meds) {
          for (final t in med.scheduledTimes) {
            final key = DateFormat('h:mm a').format(t);
            (groups[key] ??= []).add(med);
          }
        }

        return Column(
          children: groups.entries.map((entry) {
            return _TimelineGroup(
              timeLabel: entry.key,
              medications: entry.value,
              logState: logState,
              onLog: (med, scheduledAt) => _handleLog(context, ref, med, scheduledAt),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleLog(
    BuildContext ctx, WidgetRef ref,
    MedicationEntity med, DateTime scheduledAt,
  ) async {
    HapticFeedback.mediumImpact();
    final result = await ref.read(medicationLogStateProvider.notifier)
        .logDose(medicationId: med.id, scheduledAt: scheduledAt);

    if (!ctx.mounted) return;

    if (result.isSuccess) {
      _showSnack(ctx, ref, '${med.name} logged ✓', showUndo: true);
    } else if (result.isDuplicate) {
      _showDuplicateSheet(ctx, ref, med, result.lastLoggedAt!, result.minutesAgo!);
    } else if (result.isError) {
      _showSnack(ctx, ref, result.error ?? 'Error', color: AppColors.error);
    }
  }

  void _showSnack(BuildContext ctx, WidgetRef ref, String msg, {bool showUndo = false, Color? color}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? AppColors.text1,
        action: showUndo ? SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryMid,
          onPressed: () => ref.read(medicationLogStateProvider.notifier).undoLastLog(),
        ) : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showDuplicateSheet(BuildContext ctx, WidgetRef ref,
      MedicationEntity med, DateTime lastLoggedAt, int minutesAgo) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DuplicateDoseSheet(
        medication: med,
        lastLoggedAt: lastLoggedAt,
        minutesAgo: minutesAgo,
        onForceLog: () async {
          Navigator.pop(ctx);
          final scheduledAt = med.scheduledTimes.firstOrNull ?? DateTime.now();
          final r = await ref.read(medicationLogStateProvider.notifier)
              .logDose(medicationId: med.id, scheduledAt: scheduledAt, forceLog: true);
          if (ctx.mounted && r.isSuccess) {
            _showSnack(ctx, ref, '${med.name} force-logged', showUndo: true);
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  Widget _buildSkeleton() => Column(
    children: List.generate(3, (_) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 80,
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(16)),
    )),
  );

  Widget _buildError(Object e) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(16)),
    child: Text('Failed to load timeline: $e', style: const TextStyle(color: AppColors.error)),
  );

  Widget _buildEmpty() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
    child: const Center(child: Column(children: [
      Icon(Icons.check_circle_outline_rounded, size: 40, color: AppColors.secondary),
      SizedBox(height: 12),
      Text('No medications scheduled for today', style: TextStyle(color: AppColors.text3)),
    ])),
  );
}

// ── Timeline Group (time slot) ─────────────────────────────────────────────────

class _TimelineGroup extends StatelessWidget {
  final String timeLabel;
  final List<MedicationEntity> medications;
  final Map<String, String> logState;
  final Future<void> Function(MedicationEntity, DateTime) onLog;

  const _TimelineGroup({
    required this.timeLabel,
    required this.medications,
    required this.logState,
    required this.onLog,
  });

  bool _isNow() {
    final now = DateTime.now();
    // parse time label to check proximity
    try {
      final parts = timeLabel.split(':');
      var h = int.parse(parts[0]);
      final rest = parts[1].split(' ');
      final m = int.parse(rest[0]);
      final pm = rest[1] == 'PM';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      final diff = now.hour * 60 + now.minute - (h * 60 + m);
      return diff.abs() <= 30;
    } catch (_) { return false; }
  }

  @override
  Widget build(BuildContext context) {
    final now = _isNow();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time label + connector
        Row(
          children: [
            Container(
              width: 48,
              child: Text(timeLabel,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: now ? AppColors.primary : AppColors.text3,
                  letterSpacing: 0.3,
                )),
            ),
            if (now) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: const Text('Now', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ...medications.map((med) => _TimelineItem(
          medication: med,
          logState: logState,
          isNowSlot: now,
          onLog: (m) => onLog(m, med.scheduledTimes.firstOrNull ?? DateTime.now()),
        )),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Single Timeline Item ───────────────────────────────────────────────────────

class _TimelineItem extends StatefulWidget {
  final MedicationEntity medication;
  final Map<String, String> logState;
  final bool isNowSlot;
  final void Function(MedicationEntity) onLog;

  const _TimelineItem({
    required this.medication,
    required this.logState,
    required this.isNowSlot,
    required this.onLog,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> {
  bool _pressed = false;

  String get _status => widget.logState[widget.medication.id] ?? MedicationStatus.upcoming;
  bool get _isDone => _status == MedicationStatus.completed;

  Color get _borderColor {
    switch (_status) {
      case MedicationStatus.completed:  return Colors.transparent;
      case MedicationStatus.inProgress: return AppColors.primary;
      case MedicationStatus.overdue:    return AppColors.error;
      default: return AppColors.primary.withOpacity(0.25);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isDone ? 0.42 : 1.0,
      duration: const Duration(milliseconds: 280),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(_isDone ? 0 : (widget.isNowSlot ? 2 : 0), 0, 0),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: _borderColor, width: 3)),
          boxShadow: _isDone ? null : AppColors.cardShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _isDone ? AppColors.background : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isDone ? Icons.check_rounded : Icons.medication_rounded,
                  color: _isDone ? AppColors.text3 : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Name & dosage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.medication.name,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _isDone ? AppColors.text3 : AppColors.text1,
                        decoration: _isDone ? TextDecoration.lineThrough : null,
                      )),
                    const SizedBox(height: 2),
                    Text(widget.medication.dosage,
                      style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                  ],
                ),
              ),

              // Log button
              if (!_isDone)
                GestureDetector(
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) { setState(() => _pressed = false); widget.onLog(widget.medication); },
                  onTapCancel: () => setState(() => _pressed = false),
                  child: AnimatedScale(
                    scale: _pressed ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 80),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isNowSlot ? AppColors.primary : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Take',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: widget.isNowSlot ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
