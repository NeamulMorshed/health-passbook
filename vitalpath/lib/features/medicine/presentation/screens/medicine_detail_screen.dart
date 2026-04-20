import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../providers/medicine_provider.dart';

/// Medicine detail screen — adherence chart, log history, dose actions.
class MedicineDetailScreen extends ConsumerWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(medicinesProvider);

    return medicinesAsync.when(
      data: (medicines) {
        final medicine = medicines.where((m) => m.id == medicineId).firstOrNull;
        if (medicine == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Medicine not found')),
          );
        }

        final colorHex = medicine.colorHex.replaceAll('#', '');
        final cardColor = Color(int.parse('FF$colorHex', radix: 16));

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: CustomScrollView(
            slivers: [
              // Hero app bar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: cardColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cardColor, cardColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              medicine.name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${medicine.dosage.toStringAsFixed(0)} ${medicine.unit} · ${medicine.frequency.replaceAll('_', ' ')}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => context.push(
                      AppConstants.routeMedicineEdit,
                      extra: medicine,
                    ),
                    icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Stats row
                    Row(
                      children: [
                        _StatCard(
                          label: 'Inventory',
                          value: '${medicine.inventoryCount}',
                          unit: medicine.unit,
                          icon: Icons.inventory_2_rounded,
                          color: medicine.inventoryCount <= medicine.refillThreshold
                              ? AppColors.accentOrange
                              : AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Refill at',
                          value: '${medicine.refillThreshold}',
                          unit: 'remaining',
                          icon: Icons.notifications_rounded,
                          color: AppColors.info,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Schedule
                    _InfoSection(
                      title: 'Schedule',
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Start Date',
                            value: DateFormat('MMM d, yyyy').format(medicine.startDate),
                          ),
                          if (medicine.endDate != null)
                            _InfoRow(
                              icon: Icons.event_rounded,
                              label: 'End Date',
                              value: DateFormat('MMM d, yyyy').format(medicine.endDate!),
                            ),
                          _InfoRow(
                            icon: Icons.access_time_rounded,
                            label: 'Times',
                            value: medicine.scheduledTimes
                                .replaceAll('[', '').replaceAll(']', '')
                                .replaceAll('"', ''),
                          ),
                        ],
                      ),
                    ),

                    if (medicine.notes != null && medicine.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _InfoSection(
                        title: 'Instructions',
                        child: Text(
                          medicine.notes!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _DoseActionBar(
            medicineId: medicine.id,
            medicineName: medicine.name,
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseActionBar extends ConsumerWidget {
  final String medicineId;
  final String medicineName;

  const _DoseActionBar({
    required this.medicineId,
    required this.medicineName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _log(ref, 'skipped'),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Skip'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _log(ref, 'taken'),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Log as Taken'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _log(WidgetRef ref, String action) async {
    await ref.read(medicineLogNotifierProvider.notifier).logDose(
          medicineId: medicineId,
          medicineName: medicineName,
          action: action,
          scheduledAt: DateTime.now(),
        );
  }
}
