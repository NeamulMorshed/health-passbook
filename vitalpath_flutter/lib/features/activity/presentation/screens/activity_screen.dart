import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyData = ref.watch(weeklyActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('Activity & Vitals')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Weekly bar chart
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadows,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Steps This Week',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 140,
                        child: BarChart(BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 12000,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(sideTitles: SideTitles(
                              showTitles: true, reservedSize: 28,
                              getTitlesWidget: (val, _) {
                                final day = weeklyData[val.toInt()];
                                return Text(DateFormat('E').format(day.date)[0],
                                  style: const TextStyle(fontSize: 11, color: AppColors.text3));
                              },
                            )),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          barGroups: weeklyData.asMap().entries.map((e) {
                            final isToday = e.key == 6;
                            return BarChartGroupData(x: e.key, barRods: [
                              BarChartRodData(
                                toY: e.value.steps.toDouble(),
                                color: isToday ? AppColors.primary : AppColors.primaryLight,
                                width: 24, borderRadius: BorderRadius.circular(6),
                              ),
                            ]);
                          }).toList(),
                        )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Vitals grid
                const Text('Today\'s Vitals',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10, mainAxisSpacing: 10,
                  childAspectRatio: 1.4,
                  children: [
                    _VitalCard(icon: Icons.favorite_rounded, label: 'Heart Rate', value: '72 bpm', color: AppColors.error),
                    _VitalCard(icon: Icons.bloodtype_rounded, label: 'Blood Sugar', value: '5.4 mmol/L', color: AppColors.warning),
                    _VitalCard(icon: Icons.monitor_heart_rounded, label: 'Blood Pressure', value: '118/78', color: AppColors.primary),
                    _VitalCard(icon: Icons.air_rounded, label: 'SpO₂', value: '98%', color: AppColors.secondary),
                  ],
                ),
                const SizedBox(height: 12),

                // §5.4 Timezone demo
                _TimezoneCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _VitalCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadows,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text3, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
          ],
        ),
      ],
    ),
  );
}

class _TimezoneCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.warning.withOpacity(0.35)),
    ),
    child: Row(
      children: [
        const Icon(Icons.schedule_rounded, color: AppColors.warning),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('§5.4 Timezone Demo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Tap to simulate timezone change', style: TextStyle(fontSize: 12, color: AppColors.text3)),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _showTimezoneDialog(context),
          child: const Text('Demo'),
        ),
      ],
    ),
  );

  void _showTimezoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.schedule_rounded, color: AppColors.warning),
          SizedBox(width: 10),
          Text('Timezone Change', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'You\'ve crossed into a new timezone.\nEST → PST (−3 hrs)\n\nHow should VitalPath adjust your schedule?',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('Keep original')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('Adjust to local')),
        ],
      ),
    );
  }
}
