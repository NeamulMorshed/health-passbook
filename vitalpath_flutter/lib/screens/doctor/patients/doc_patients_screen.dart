import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/patient.dart';

class DocPatientsScreen extends ConsumerWidget {
  const DocPatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Patients'),
        automaticallyImplyLeading: false,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'),
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (context.mounted) context.go('/user-select'); },
            );
            return const Center(child: SizedBox.shrink());
          }
          final patientsAsync = ref.watch(doctorPatientsStreamProvider(user.uid));

          return patientsAsync.when(
            loading: () => const _ShimmerPatientList(),
            error: (_, __) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'),
            data: (patients) {
              if (patients.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No Patients Yet',
                  subtitle: 'Patients will appear here once they book an appointment with you.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: patients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _PatientCard(patient: patients[i], doctorId: user.uid),
              );
            },
          );
        },
      ),
    );
  }
}

class _PatientCard extends ConsumerWidget {
  final PatientProfile patient;
  final String doctorId;
  const _PatientCard({required this.patient, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/doc/patient/${patient.uid}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          AppAvatar(name: patient.name, size: 48),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(patient.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter')),
                const SizedBox(height: 4),
                Row(children: [
                  if (patient.age != null) _InfoChip('${patient.age} yrs'),
                  if (patient.age != null) const SizedBox(width: 6),
                  if (patient.bloodType != null)
                    _InfoChip(patient.bloodType!),
                  if (patient.bloodType != null) const SizedBox(width: 6),
                  if (patient.conditions.isNotEmpty)
                    _InfoChip(patient.conditions.first),
                ]),
              ])),
          IconButton(
            tooltip: 'Remove patient',
            icon: const Icon(Icons.person_remove_rounded,
                size: 18, color: AppColors.destructive),
            onPressed: () => _confirmRemove(context, ref),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.mutedForeground),
        ]),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Patient',
            style: TextStyle(fontFamily: 'Inter')),
        content: Text('Remove ${patient.name} from your patients list?',
            style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref
                  .read(connectionNotifierProvider.notifier)
                  .remove(patient.uid, doctorId);
              if (context.mounted) {
                showAppSnack(
                    context, '${patient.name} removed from your list.');
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
  );
}

class _ShimmerPatientList extends StatelessWidget {
  const _ShimmerPatientList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.muted,
      highlightColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
