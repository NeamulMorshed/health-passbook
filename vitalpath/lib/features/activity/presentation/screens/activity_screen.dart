import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/health_connector_service.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/widgets/step_progress_card.dart';

/// Activity tracking screen — steps, GPS walks, history chart (SRS §4.3).
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepDataAsync = ref.watch(liveStepDataProvider);
    final historyAsync = ref.watch(_stepHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(liveStepDataProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Step progress card
          stepDataAsync.when(
            data: (data) => StepProgressCard(
              stepCount: data.stepCount,
              stepGoal: AppConstants.defaultStepGoal,
              distanceKm: data.distanceKm,
            ),
            loading: () => const _ShimmerBox(height: 160),
            error: (_, __) => const _StepPermissionBanner(),
          ).animate().fadeIn(),

          const SizedBox(height: 24),

          // GPS Walk CTA
          _GpsWalkCard(
            onTap: () => context.push(AppConstants.routeGpsWalk),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 24),

          // 7-day history chart
          _HistoryChartSection(historyAsync: historyAsync),
        ],
      ),
    );
  }
}

@Riverpod(keepAlive: false)
Future<List<DailyStepData>> _stepHistory(Ref ref) {
  return ref.watch(healthConnectorServiceProvider).fetchStepHistory(days: 7);
}

class _GpsWalkCard extends StatelessWidget {
  final VoidCallback onTap;

  const _GpsWalkCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.directions_walk_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start GPS Walk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Track your route with GPS & get haptic feedback every km',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _HistoryChartSection extends StatelessWidget {
  final AsyncValue<List<DailyStepData>> historyAsync;

  const _HistoryChartSection({required this.historyAsync});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last 7 Days',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          data: (history) {
            if (history.isEmpty) {
              return const _ShimmerBox(height: 160);
            }
            return Container(
              height: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: AppConstants.defaultStepGoal.toDouble() * 1.2,
                  barGroups: history.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.steps.toDouble(),
                          color: e.value.steps >= AppConstants.defaultStepGoal
                              ? AppColors.success
                              : AppColors.primary,
                          width: 20,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= history.length) return const SizedBox.shrink();
                          final date = history[value.toInt()].date;
                          final parts = date.split('-');
                          return Text(
                            '${parts[2]}',
                            style: const TextStyle(
                              fontSize: 10, color: AppColors.textTertiary),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            );
          },
          loading: () => const _ShimmerBox(height: 180),
          error: (_, __) => const _ShimmerBox(height: 180),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _StepPermissionBanner extends StatelessWidget {
  const _StepPermissionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.health_and_safety_rounded, color: AppColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Health Connect permission required to track steps.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.divider);
  }
}
