import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../models/vital_reading.dart';
import '../../providers/vitals_provider.dart';

// Line color per vital type.
Color _lineColor(String type) => switch (type) {
      VitalType.bpSystolic => AppColors.destructive,
      VitalType.bpDiastolic => AppColors.info,
      VitalType.glucose => AppColors.warning,
      VitalType.pulse => AppColors.primary,
      VitalType.spo2 => AppColors.success,
      VitalType.temp => AppColors.caregiver,
      _ => AppColors.mutedForeground,
    };

/// Shared mini/full line-chart widget for one or more vital types.
///
/// Shows the last 30 days of readings. If fewer than 2 data points exist for
/// any type, a "Not enough data" fallback is shown instead of crashing.
///
/// [types] is a non-empty list of VitalType constants. When multiple types are
/// provided (e.g. BP systolic + diastolic) each gets its own coloured line.
class VitalTrendChart extends ConsumerWidget {
  final String patientId;
  final List<String> types;

  /// Height of the chart area (excluding legend). Defaults to 140.
  final double height;

  /// Show a bottom axis with day labels. Defaults to false (mini mode).
  final bool showAxis;

  const VitalTrendChart({
    super.key,
    required this.patientId,
    required this.types,
    this.height = 140,
    this.showAxis = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allReadings = ref.watch(vitalsProvider(patientId)).asData?.value ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    // Build per-type data (ascending by date, last 30 days only).
    final Map<String, List<VitalReading>> byType = {
      for (final t in types)
        t: allReadings
            .where((r) => r.type == t && r.recordedAt.isAfter(cutoff))
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)),
    };

    // Need at least 2 points across all types to draw a meaningful chart.
    final hasEnough = byType.values.any((list) => list.length >= 2);
    if (!hasEnough) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Not enough data\nLog readings to see trends',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    // Compute global x-axis bounds (epoch ms → double).
    final allPoints = byType.values.expand((l) => l).toList();
    final minX =
        allPoints.map((r) => r.recordedAt.millisecondsSinceEpoch.toDouble()).reduce((a, b) => a < b ? a : b);
    final maxX =
        allPoints.map((r) => r.recordedAt.millisecondsSinceEpoch.toDouble()).reduce((a, b) => a > b ? a : b);

    // Compute global y-axis bounds with padding.
    final allValues = allPoints.map((r) => r.value).toList();
    final dataMin = allValues.reduce((a, b) => a < b ? a : b);
    final dataMax = allValues.reduce((a, b) => a > b ? a : b);

    // Normal range band from the first type (used for horizontal band).
    final (normMin, normMax) = VitalType.normalRange(types.first);
    final yPad = ((dataMax - dataMin) * 0.15).clamp(2.0, 20.0);
    final minY = (dataMin - yPad).clamp(0.0, double.infinity);
    final maxY = dataMax + yPad;

    // Build LineBarsData.
    final lineBars = types
        .where((t) => byType[t]!.length >= 2)
        .map((t) {
          final spots = byType[t]!
              .map((r) => FlSpot(
                    r.recordedAt.millisecondsSinceEpoch.toDouble(),
                    r.value,
                  ))
              .toList();
          final color = _lineColor(t);
          return LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              show: spots.length <= 10,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 1.5,
                strokeColor: AppColors.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: types.length == 1,
              color: color.withValues(alpha: 0.08),
            ),
          );
        })
        .toList();

    // Normal-range horizontal band lines.
    final bandMin = normMin.clamp(minY, maxY);
    final bandMax = normMax.clamp(minY, maxY);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              lineBarsData: lineBars,
              // Normal-range shaded band.
              betweenBarsData: [
                if (types.length == 1)
                  BetweenBarsData(
                    fromIndex: 0,
                    toIndex: 0,
                    color: Colors.transparent,
                  ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: bandMin,
                    color: AppColors.success.withValues(alpha: 0.35),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: showAxis,
                      alignment: Alignment.topLeft,
                      labelResolver: (_) =>
                          '${bandMin.toStringAsFixed(0)} (low)',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.success),
                    ),
                  ),
                  HorizontalLine(
                    y: bandMax,
                    color: AppColors.success.withValues(alpha: 0.35),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: showAxis,
                      alignment: Alignment.topLeft,
                      labelResolver: (_) =>
                          '${bandMax.toStringAsFixed(0)} (high)',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.success),
                    ),
                  ),
                ],
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border.withValues(alpha: 0.5),
                  strokeWidth: 0.8,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: showAxis,
                    reservedSize: 36,
                    getTitlesWidget: (value, _) => Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.mutedForeground),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: showAxis,
                    reservedSize: 24,
                    interval: (maxX - minX) / 4,
                    getTitlesWidget: (value, _) {
                      final date = DateTime.fromMillisecondsSinceEpoch(
                          value.toInt());
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MMM d').format(date),
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.mutedForeground),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.foreground.withValues(alpha: 0.85),
                  getTooltipItems: (spots) => spots.map((s) {
                    final type = types.length > s.barIndex
                        ? types[s.barIndex]
                        : types.first;
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} ${VitalType.unitFor(type)}',
                      const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    );
                  }).toList(),
                ),
              ),
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),
        // Legend row when multiple lines.
        if (types.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: types.map((t) {
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 12,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _lineColor(t),
                      borderRadius: BorderRadius.circular(2),
                    )),
                const SizedBox(width: 4),
                Text(
                  VitalType.labelFor(t),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.mutedForeground),
                ),
              ]);
            }).toList(),
          ),
        ],
      ],
    );
  }
}
