import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_colors.dart';
import '../../../medication/domain/entities/medication_entity.dart';
import '../providers/doctor_provider.dart';
import '../../../medication/presentation/providers/medication_provider.dart';

class DoctorPatientScreen extends ConsumerStatefulWidget {
  final String patientId;
  const DoctorPatientScreen({super.key, required this.patientId});
  @override
  ConsumerState<DoctorPatientScreen> createState() => _DoctorPatientScreenState();
}

class _DoctorPatientScreenState extends ConsumerState<DoctorPatientScreen> {
  // Mock prescriptions
  final List<Map<String, dynamic>> _prescriptions = [
    {'id': 'rx1', 'name': 'Metformin 500mg', 'dose': 'Twice daily · 8 AM & 8 PM', 'verified': true},
    {'id': 'rx2', 'name': 'Lisinopril 10mg',  'dose': 'Once daily · 7 AM with food', 'verified': true},
    {'id': 'rx3', 'name': 'Atorvastatin 20mg','dose': 'Once daily · bedtime', 'verified': false},
  ];

  void _showAddRxSheet() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const Text('Add Prescription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Will be sent to patient for confirmation.', style: TextStyle(fontSize: 13, color: AppColors.text3)),
            const SizedBox(height: 20),
            const Text('MEDICATION NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.text3)),
            const SizedBox(height: 6),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Aspirin 81mg')),
            const SizedBox(height: 14),
            const Text('DOSAGE & FREQUENCY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.text3)),
            const SizedBox(height: 6),
            TextField(controller: doseCtrl, decoration: const InputDecoration(hintText: 'e.g. Once daily at 9 AM')),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    setState(() => _prescriptions.add({
                      'id': 'rx_new_${DateTime.now().millisecond}',
                      'name': nameCtrl.text.trim(),
                      'dose': doseCtrl.text.trim().isNotEmpty ? doseCtrl.text.trim() : 'As prescribed',
                      'verified': false,
                      'isNew': true,
                    }));
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription sent to patient')));
                },
                child: const Text('Send to Patient'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete(int idx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 26)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delete Verified Entry?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('SRS §4.4 — cannot be undone', style: TextStyle(fontSize: 11, color: AppColors.text3)),
            ])),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withOpacity(0.2))),
            child: const Text(
              'This prescription has been verified by a licensed provider. Deleting it will remove it from the patient\'s active list and trigger a notification.',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                setState(() => _prescriptions.removeAt(idx));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription deleted · Patient notified'),
                      backgroundColor: AppColors.error));
              },
              child: const Text('Delete Anyway'),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(selectedPatientProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Dark gradient hero
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                              ),
                              child: Center(child: Text(
                                patient?.initials ?? 'SJ',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                              )),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(patient?.name ?? 'Sarah Johnson',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                Text('${patient?.primaryCondition ?? 'Condition'} · ${patient?.gender ?? 'F'} · Age ${patient?.age ?? 36}',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Adherence ring + 7-day dots
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64, height: 64,
                                child: CustomPaint(
                                  painter: _AdherenceRingPainter(pct: patient?.adherenceRate ?? 0.85),
                                  child: Center(child: Text(
                                    '${((patient?.adherenceRate ?? 0.85) * 100).round()}%',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                  )),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('7-Day Adherence', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: (patient?.weeklyDots ?? [true,true,true,false,true,true,true])
                                        .map((done) => Container(
                                      width: 26, height: 26, margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: done ? Colors.white : Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: done ? const Icon(Icons.check_rounded, size: 12, color: AppColors.primary) : null,
                                    )).toList(),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Prescription list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Prescriptions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ElevatedButton.icon(
                      onPressed: _showAddRxSheet,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Rx'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._prescriptions.asMap().entries.map((e) {
                  final rx = e.value;
                  final isNew = rx['isNew'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: isNew ? Border.all(color: AppColors.primary, width: 2) : null,
                      boxShadow: AppColors.cardShadows,
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: rx['verified'] == true ? AppColors.primaryLight : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.medication_rounded,
                          color: rx['verified'] == true ? AppColors.primary : AppColors.warning, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(rx['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(rx['dose']!, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isNew ? AppColors.primaryLight
                                : rx['verified'] == true ? AppColors.secondaryLight
                                : AppColors.warningLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isNew ? 'New' : rx['verified'] == true ? 'Verified' : 'Pending',
                            style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: isNew ? AppColors.primary
                                  : rx['verified'] == true ? AppColors.secondary
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () { HapticFeedback.lightImpact(); _confirmDelete(e.key); },
                          child: const Text('Delete',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)),
                        ),
                      ]),
                    ]),
                  ).animate().fadeIn(duration: 400.ms, delay: (e.key * 60).ms);
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceRingPainter extends CustomPainter {
  final double pct;
  _AdherenceRingPainter({required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = (size.width - 8) / 2;
    final bg = Paint()..color = Colors.white.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 5;
    final fg = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, bg);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * pct, false, fg);
  }

  @override
  bool shouldRepaint(_AdherenceRingPainter old) => old.pct != pct;
}
