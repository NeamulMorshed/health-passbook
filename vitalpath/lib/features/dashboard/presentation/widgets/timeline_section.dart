import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';

enum TimelineItemStatus { completed, upcoming, skipped, missed }

class TimelineItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final TimelineItemStatus status;
  final bool isVerified;
  final String colorHex;

  const TimelineItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
    required this.isVerified,
    required this.colorHex,
  });
}

/// Vertical timeline section — the signature VitalPath UI element (SRS §7).
/// Completed tasks are "faded"; upcoming are "elevated" (SRS §7).
class TimelineSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<TimelineItem> items;
  final VoidCallback onAddPressed;

  const TimelineSection({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (items.isEmpty)
          _EmptyState(title: title, onAddPressed: onAddPressed)
        else
          // Timeline items
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return _TimelineRow(
              item: item,
              isLast: isLast,
              animationDelay: (index * 80).ms,
            );
          }),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineItem item;
  final bool isLast;
  final Duration animationDelay;

  const _TimelineRow({
    required this.item,
    required this.isLast,
    required this.animationDelay,
  });

  Color get _statusColor => switch (item.status) {
        TimelineItemStatus.completed => AppColors.success,
        TimelineItemStatus.skipped => AppColors.textTertiary,
        TimelineItemStatus.missed => AppColors.error,
        TimelineItemStatus.upcoming => AppColors.primary,
      };

  bool get _isCompleted => item.status == TimelineItemStatus.completed ||
      item.status == TimelineItemStatus.skipped;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline track
        Column(
          children: [
            // Status circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isCompleted
                    ? _statusColor.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isCompleted ? _statusColor : AppColors.primary,
                  width: _isCompleted ? 1.5 : 2,
                ),
              ),
              child: Icon(
                _statusIcon,
                size: 16,
                color: _statusColor,
              ),
            ),
            // Vertical line
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: AppColors.divider,
              ),
          ],
        ),

        const SizedBox(width: 12),

        // Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedOpacity(
              opacity: _isCompleted ? 0.55 : 1.0, // Faded state for completed (SRS §7)
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isCompleted
                      ? AppColors.surfaceAlt
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: item.status == TimelineItemStatus.upcoming
                        ? AppColors.primary.withOpacity(0.2)
                        : AppColors.divider,
                    width: 1,
                  ),
                  boxShadow: item.status == TimelineItemStatus.upcoming
                      ? AppColors.cardShadow // Elevated for upcoming (SRS §7)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isCompleted
                                        ? AppColors.textTertiary
                                        : AppColors.textPrimary,
                                    decoration: item.status ==
                                            TimelineItemStatus.skipped
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (item.isVerified)
                                const Tooltip(
                                  message: 'Verified by doctor',
                                  child: Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: AppColors.info,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Time + Action
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.time.isNotEmpty)
                          Text(
                            item.time,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        if (item.status == TimelineItemStatus.upcoming) ...[
                          const SizedBox(height: 6),
                          _LogButton(itemId: item.id),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: animationDelay, duration: 300.ms).slideX(
              begin: 0.05,
              end: 0,
            ),
      ],
    );
  }

  IconData get _statusIcon => switch (item.status) {
        TimelineItemStatus.completed => Icons.check_rounded,
        TimelineItemStatus.skipped => Icons.skip_next_rounded,
        TimelineItemStatus.missed => Icons.close_rounded,
        TimelineItemStatus.upcoming => Icons.radio_button_unchecked_rounded,
      };
}

class _LogButton extends StatelessWidget {
  final String itemId;

  const _LogButton({required this.itemId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Haptic BEFORE animation (Antigravity — Tech Blueprint §3)
        await HapticService().logAction();
        // TODO: Dispatch log action via provider
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Log',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final VoidCallback onAddPressed;

  const _EmptyState({required this.title, required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 32, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              'No $title added yet',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: onAddPressed, child: const Text('Add now')),
          ],
        ),
      ),
    );
  }
}
