import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../core/theme/app_theme.dart';
import '../models/drug_interaction.dart';

/// Shows the result of an interaction check inline in the prescription review.
///
/// States:
///  • [isLoading] = true → subtle spinner row
///  • interactions empty + done → green "no interactions" confirmation
///  • interactions non-empty → collapsible warning cards, severity-coloured
class InteractionWarningCard extends StatefulWidget {
  final List<DrugInteraction> interactions;
  final bool isLoading;
  final bool isDone;

  const InteractionWarningCard({
    super.key,
    required this.interactions,
    this.isLoading = false,
    this.isDone = false,
  });

  @override
  State<InteractionWarningCard> createState() => _InteractionWarningCardState();
}

class _InteractionWarningCardState extends State<InteractionWarningCard> {
  static const _previewCount = 2;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _buildLoadingRow();
    if (widget.isDone && widget.interactions.isEmpty) return _buildClearRow();
    if (widget.interactions.isEmpty) return const SizedBox.shrink();

    return _buildWarningList();
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoadingRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.mutedForeground),
        ),
        SizedBox(width: 10),
        Text(
          'Checking for drug interactions…',
          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
        ),
      ]),
    );
  }

  // ── No interactions ───────────────────────────────────────────────────────

  Widget _buildClearRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            color: AppColors.success,
            size: 15),
        SizedBox(width: 8),
        Text(
          'No known drug interactions detected.',
          style: TextStyle(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  // ── Interaction list ──────────────────────────────────────────────────────

  Widget _buildWarningList() {
    final hasMajor =
        widget.interactions.any((i) => i.severity == InteractionSeverity.major);

    final preview = widget.interactions.take(_previewCount).toList();
    final rest = widget.interactions.skip(_previewCount).toList();
    final shown = _expanded ? widget.interactions : preview;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: hasMajor ? AppColors.destructiveLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasMajor
              ? AppColors.destructive.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              Icon(
                hasMajor ? Icons.warning_rounded : Icons.info_outline_rounded,
                size: 15,
                color: hasMajor ? AppColors.destructive : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.interactions.length} drug interaction${widget.interactions.length == 1 ? '' : 's'} detected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hasMajor ? AppColors.destructive : AppColors.warning,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 8),

          // Interaction rows
          ...shown.map((i) => _InteractionRow(interaction: i)),

          // Show more / less toggle
          if (rest.isNotEmpty || _expanded) ...[
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Text(
                  _expanded
                      ? 'Show fewer'
                      : '+ ${rest.length} more interaction${rest.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasMajor ? AppColors.destructive : AppColors.warning,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Single interaction row ────────────────────────────────────────────────────

class _InteractionRow extends StatefulWidget {
  final DrugInteraction interaction;
  const _InteractionRow({required this.interaction});

  @override
  State<_InteractionRow> createState() => _InteractionRowState();
}

class _InteractionRowState extends State<_InteractionRow> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.interaction;
    final color = _severityColor(i.severity);

    return GestureDetector(
      onTap: () => setState(() => _showDetail = !_showDetail),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  i.severity.label,
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_titleCase(i.drugAName)} ↔ ${_titleCase(i.drugBName)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _showDetail
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowUp01,
                      color: AppColors.mutedForeground,
                      size: 16)
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      color: AppColors.mutedForeground,
                      size: 16),
            ]),
            if (_showDetail) ...[
              const SizedBox(height: 6),
              Text(
                i.description,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.cardForeground, height: 1.5),
              ),
              if (i.source.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Source: ${i.source}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.mutedForeground),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Color _severityColor(InteractionSeverity s) {
    switch (s) {
      case InteractionSeverity.major:
        return AppColors.destructive;
      case InteractionSeverity.moderate:
        return AppColors.warning;
      case InteractionSeverity.minor:
        return const Color(0xFFD97706);
      case InteractionSeverity.unknown:
        return AppColors.primary;
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
