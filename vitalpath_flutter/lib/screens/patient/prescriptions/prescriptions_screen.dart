import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
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
      backgroundColor: AppColors.pageBackground,
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
          final patientId = user.uid;
          final rxAsync = ref.watch(patientPrescriptionsProvider(patientId));
          return rxAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: 'Pull to refresh or try again.'),
            data: (rxList) {
              if (rxList.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(patientPrescriptionsProvider(patientId)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: const [
                      SizedBox(height: 200),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Prescriptions Yet',
                        subtitle: 'Prescriptions from your doctors will appear here.',
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(patientPrescriptionsProvider(patientId)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: rxList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _RxCard(rx: rxList[i]),
                ),
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

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RxDetailSheet(rx: rx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = rx.documentUrl != null && (rx.documentUrl as String).isNotEmpty;
    return BentoCard(
      onTap: () => _showDetail(context),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prescription photo thumbnail
          if (hasPhoto)
            CachedNetworkImage(
              imageUrl: rx.documentUrl as String,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 140,
                color: AppColors.muted,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 60,
                color: AppColors.muted,
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_rounded,
                          size: 16, color: AppColors.mutedForeground),
                      SizedBox(width: 6),
                      Text('Could not load image',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground)),
                    ],
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dr. ${rx.doctorName}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            DateFormat('MMM d, y').format(rx.issuedAt),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedForeground),
                          ),
                        ]),
                  ),
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.mutedForeground, size: 14),
                ]),

                if (rx.diagnosis != null &&
                    (rx.diagnosis as String).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  BentoCard(
                    color: AppColors.muted,
                    padding: const EdgeInsets.all(10),
                    child: Text(rx.diagnosis as String,
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.mutedForeground)),
                  ),
                ],

                const SizedBox(height: 12),
                const Text('Medicines',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground)),
                const SizedBox(height: 6),
                ...((rx.medicines as List?)?.cast<dynamic>() ?? []).map<Widget>((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.circle,
                            size: 5, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${m.name}  ${m.dosage}  •  ${m.frequency}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ]),
                    )),

                if (rx.notes != null &&
                    (rx.notes as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Note: ${rx.notes}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground)),
                ],

                if (hasPhoto) ...[
                  const SizedBox(height: 10),
                  const Row(children: [
                    Icon(Icons.image_rounded,
                        size: 13, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Tap to view prescription photo',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Prescription detail bottom sheet ──────────────────────────────────────────

class _RxDetailSheet extends StatelessWidget {
  final dynamic rx;
  const _RxDetailSheet({required this.rx});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = rx.documentUrl != null &&
        (rx.documentUrl as String).isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedNote, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. ${rx.doctorName}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text(
                        DateFormat('MMMM d, y').format(rx.issuedAt),
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground),
                      ),
                    ]),
              ),
            ]),

            if (rx.diagnosis != null &&
                (rx.diagnosis as String).isNotEmpty) ...[
              const SizedBox(height: 14),
              BentoCard(
                color: AppColors.muted,
                padding: const EdgeInsets.all(12),
                child: Text(rx.diagnosis as String,
                    style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.mutedForeground)),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            const Text('Medicines',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...((rx.medicines as List?)?.cast<dynamic>() ?? []).map<Widget>((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BentoCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          if ((m.dosage as String).isNotEmpty ||
                              (m.frequency as String).isNotEmpty)
                            Text(
                              [
                                if ((m.dosage as String).isNotEmpty) m.dosage,
                                if ((m.frequency as String).isNotEmpty)
                                  m.frequency,
                              ].join('  •  '),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground),
                            ),
                          if (m.instructions != null &&
                              (m.instructions as String).isNotEmpty)
                            Text(m.instructions as String,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground,
                                    fontStyle: FontStyle.italic)),
                        ]),
                  ),
                )),

            if (rx.notes != null && (rx.notes as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              BentoCard(
                color: AppColors.muted,
                padding: const EdgeInsets.all(12),
                child: Text('Note: ${rx.notes}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground)),
              ),
            ],

            // Prescription photo
            if (hasPhoto) ...[
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              const Text('Prescription Photo',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: rx.documentUrl as String,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Icon(Icons.broken_image_rounded,
                              size: 48,
                              color: AppColors.mutedForeground),
                        ),
                      ),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: rx.documentUrl as String,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: AppColors.muted,
                      child:
                          const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 80,
                      color: AppColors.muted,
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded,
                                size: 18,
                                color: AppColors.mutedForeground),
                            SizedBox(width: 8),
                            Text('Could not load image',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Tap to view full size',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground)),
            ],
          ],
        ),
      ),
    );
  }
}
