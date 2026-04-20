import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/medicine_provider.dart';
import '../widgets/medicine_card.dart';

/// Medicine list — shows all active medications (SRS §4.1).
class MedicineListScreen extends ConsumerWidget {
  const MedicineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(medicinesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Medications'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppConstants.routeMedicineAdd),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Medication',
          ),
        ],
      ),
      body: medicinesAsync.when(
        data: (medicines) {
          if (medicines.isEmpty) {
            return _EmptyMedicines(
              onAdd: () => context.push(AppConstants.routeMedicineAdd),
            );
          }

          // Separate by refill status
          final needsRefill = medicines.where((m) => m.inventoryCount <= m.refillThreshold).toList();
          final ok = medicines.where((m) => m.inventoryCount > m.refillThreshold).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              if (needsRefill.isNotEmpty) ...[
                // Refill alert banner
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.accentOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${needsRefill.length} ${needsRefill.length == 1 ? 'medication needs' : 'medications need'} a refill',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

                const _SectionHeader(title: 'Needs Refill'),
                ...needsRefill.asMap().entries.map((e) => MedicineCard(
                      medicine: e.value,
                      animationDelay: (e.key * 60).ms,
                    )),
                const SizedBox(height: 16),
              ],

              if (ok.isNotEmpty) ...[
                if (needsRefill.isNotEmpty)
                  const _SectionHeader(title: 'Active'),
                ...ok.asMap().entries.map((e) => MedicineCard(
                      medicine: e.value,
                      animationDelay: (e.key * 60).ms,
                    )),
              ],

              const SizedBox(height: 80),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppConstants.routeMedicineAdd),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyMedicines extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyMedicines({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.medication_rounded,
                size: 40, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No medications added',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first medication to start\ntracking your health regimen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Medication'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 52)),
          ),
        ],
      ),
    );
  }
}
