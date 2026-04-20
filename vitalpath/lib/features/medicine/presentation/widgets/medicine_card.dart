import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../providers/medicine_provider.dart';

class MedicineCard extends ConsumerWidget {
  final Medicine medicine;
  final Duration animationDelay;

  const MedicineCard({
    super.key,
    required this.medicine,
    this.animationDelay = Duration.zero,
  });

  Color get _cardColor {
    final hex = medicine.colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsRefill = medicine.inventoryCount <= medicine.refillThreshold;

    return Slidable(
      key: ValueKey(medicine.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => context.push(
              '${AppConstants.routeMedicineEdit}',
              extra: medicine,
            ),
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, ref),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => context.push('${AppConstants.routeMedicineList}/detail/${medicine.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: needsRefill
                  ? AppColors.accentOrange.withOpacity(0.4)
                  : AppColors.divider,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _cardColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: _cardColor,
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            medicine.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (medicine.isVerified)
                          const Tooltip(
                            message: 'Verified by doctor',
                            child: Icon(Icons.verified_rounded,
                                size: 14, color: AppColors.info),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${medicine.dosage.toStringAsFixed(medicine.dosage.truncateToDouble() == medicine.dosage ? 0 : 1)} ${medicine.unit} · ${medicine.frequency.replaceAll('_', ' ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Inventory badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: needsRefill
                          ? AppColors.accentOrange.withOpacity(0.12)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${medicine.inventoryCount} left',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: needsRefill
                            ? AppColors.accentOrange
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: animationDelay, duration: 300.ms).slideX(begin: 0.05);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove medication?'),
        content: Text(
          'Are you sure you want to remove "${medicine.name}" from your list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(medicineFormNotifierProvider.notifier)
                  .delete(medicine.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
