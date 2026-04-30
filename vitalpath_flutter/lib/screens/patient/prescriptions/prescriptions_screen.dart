import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Prescriptions')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: 'Pull to refresh or try again.'),
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (context.mounted) context.go('/user-select'); },
            );
            return const SizedBox.shrink();
          }
          final rxAsync = ref.watch(patientPrescriptionsProvider(user.uid));
          return rxAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: 'Pull to refresh or try again.'),
            data: (rxList) {
              if (rxList.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Prescriptions Yet',
                  subtitle: 'Prescriptions from your doctors will appear here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rxList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _RxCard(rx: rxList[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _RxCard extends StatelessWidget {
  final dynamic rx;
  const _RxCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.doctorPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medication_rounded, color: AppColors.doctorPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dr. ${rx.doctorName}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              Text(
                DateFormat('MMM d, y').format(rx.issuedAt),
                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter'),
              ),
            ])),
          ]),

          if (rx.diagnosis != null && rx.diagnosis!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.muted, borderRadius: BorderRadius.circular(8)),
              child: Text(rx.diagnosis!,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                      color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ),
          ],

          const SizedBox(height: 12),
          const Text('Medicines', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground, fontFamily: 'Inter')),
          const SizedBox(height: 6),
          ...rx.medicines.map<Widget>((m) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.circle, size: 5, color: AppColors.doctorPrimary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${m.name}  ${m.dosage}  •  ${m.frequency}',
                style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
              )),
            ]),
          )),

          if (rx.notes != null && rx.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${rx.notes}',
                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ],
        ],
      ),
    );
  }
}
