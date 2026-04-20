import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/medication_provider.dart';
import '../widgets/timeline_widget.dart';

class MedicationScreen extends ConsumerWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(todayMedicationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Medications'),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Refill alert
                medsAsync.when(
                  data: (meds) {
                    final needRefill = meds.where((m) => m.needsRefill).toList();
                    if (needRefill.isEmpty) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_pharmacy_rounded, color: AppColors.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            '${needRefill.length} medication${needRefill.length > 1 ? 's' : ''} need${needRefill.length == 1 ? 's' : ''} refill soon',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                          )),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.warning),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // §5.6 Weight input demo
                _WeightInputCard(),
                const SizedBox(height: 16),

                const Text('Today\'s Schedule',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                const SizedBox(height: 12),

                const TimelineWidget(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightInputCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_WeightInputCard> createState() => _WeightInputCardState();
}

class _WeightInputCardState extends ConsumerState<_WeightInputCard> {
  final _controller = TextEditingController();
  String? _warningMsg;

  void _validate(String val) {
    final parsed = double.tryParse(val);
    if (parsed == null || val.isEmpty) { setState(() => _warningMsg = null); return; }
    if (parsed < AppConstants.weightMinKg || parsed > AppConstants.weightMaxKg) {
      setState(() => _warningMsg = '${parsed.toStringAsFixed(1)} kg is outside expected range (${AppConstants.weightMinKg}–${AppConstants.weightMaxKg} kg). Verify before saving.');
    } else {
      setState(() => _warningMsg = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.monitor_weight_outlined, color: AppColors.info, size: 18)),
            const SizedBox(width: 10),
            const Text('Log Weight', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _validate,
            decoration: const InputDecoration(
              hintText: '70.5',
              suffixText: 'kg',
              isDense: true,
            ),
          ),
          if (_warningMsg != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_warningMsg!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.5))),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// Missing import
extension on AppColors {
  static const infoLight = Color(0xFFE3F0FF);
  static const info = Color(0xFF2B91FF);
}
