import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';

/// Adherence report — shows medication compliance for doctor review (SRS §3.2).
class AdherenceReportScreen extends ConsumerWidget {
  final String patientId;

  const AdherenceReportScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Adherence Report')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary cards
          Row(
            children: [
              _AdherenceSummaryCard(
                label: 'Taken',
                count: 23,
                total: 28,
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(width: 12),
              _AdherenceSummaryCard(
                label: 'Skipped',
                count: 3,
                total: 28,
                color: AppColors.warning,
                icon: Icons.skip_next_rounded,
              ),
              const SizedBox(width: 12),
              _AdherenceSummaryCard(
                label: 'Missed',
                count: 2,
                total: 28,
                color: AppColors.error,
                icon: Icons.cancel_rounded,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4-week trend chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '4-Week Adherence Trend',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 78),
                            FlSpot(1, 82),
                            FlSpot(2, 75),
                            FlSpot(3, 88),
                          ],
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.08),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: 100,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, m) => Text(
                              '${v.toInt()}%',
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textTertiary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, m) {
                              const labels = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
                              return Text(
                                labels[v.toInt() % labels.length],
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textTertiary),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: AppColors.divider,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceSummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _AdherenceSummaryCard({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
