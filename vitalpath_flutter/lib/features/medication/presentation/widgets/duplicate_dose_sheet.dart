import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/entities/medication_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// §5.2 Duplicate Dose Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class DuplicateDoseSheet extends StatelessWidget {
  final MedicationEntity medication;
  final DateTime lastLoggedAt;
  final int minutesAgo;
  final VoidCallback onForceLog;
  final VoidCallback onCancel;

  const DuplicateDoseSheet({
    super.key,
    required this.medication,
    required this.lastLoggedAt,
    required this.minutesAgo,
    required this.onForceLog,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 8, left: 20, right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),

          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duplicate Dose Detected',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                    Text('Overdose prevention · SRS §5.2',
                      style: TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.6),
                  children: [
                    TextSpan(text: medication.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' was already logged '),
                    TextSpan(text: '$minutesAgo min${minutesAgo != 1 ? 's' : ''} ago',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' at '),
                    TextSpan(text: DateFormat('h:mm a').format(lastLoggedAt),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: '. Logging again may result in a double dose.'),
                  ],
                )),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Text('Are you sure you want to log this dose again?',
            style: TextStyle(fontSize: 13, color: AppColors.text3)),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onForceLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Log Anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
