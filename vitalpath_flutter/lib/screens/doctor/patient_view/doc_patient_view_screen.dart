import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/prescription.dart';

class DocPatientViewScreen extends ConsumerWidget {
  final String patientId;
  const DocPatientViewScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientProfileProvider(patientId));
    final medsAsync = ref.watch(medicinesProvider(patientId));
    final rxAsync = ref.watch(patientPrescriptionsProvider(patientId));
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Patient Details')),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'),
        data: (patient) {
          if (patient == null) return const EmptyState(icon: Icons.error_outline, title: 'Not Found', subtitle: 'Patient data not available.');

          return ListView(
            children: [
              // Patient header
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  AppAvatar(name: patient.name, size: 64),
                  const SizedBox(height: 12),
                  Text(patient.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _Stat('${patient.age ?? '--'}', 'Age'),
                    Container(width: 1, height: 30, color: AppColors.border),
                    _Stat('${patient.weight?.toStringAsFixed(0) ?? '--'} kg', 'Weight'),
                    Container(width: 1, height: 30, color: AppColors.border),
                    _Stat(patient.bloodType ?? '--', 'Blood'),
                    Container(width: 1, height: 30, color: AppColors.border),
                    _Stat(patient.bmi?.toStringAsFixed(1) ?? '--', 'BMI'),
                  ]),
                ]),
              ),

              if (patient.conditions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Medical Conditions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: patient.conditions.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(6)),
                      child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning, fontFamily: 'Inter')),
                    )).toList()),
                  ]),
                ),
              ],

              const SizedBox(height: 12),

              // Current medicines
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Current Medicines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  const SizedBox(height: 12),
                  medsAsync.when(
                    data: (meds) {
                      if (meds.isEmpty) return const Text('No active medicines.', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter'));
                      return Column(children: meds.map((med) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.medication_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(med.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                            Text('${med.dosage} - ${med.frequency}', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                          ])),
                          if (med.takenToday) StatusBadge.success('Taken') else StatusBadge.warning('Pending'),
                        ]),
                      )).toList());
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // Prescriptions
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Prescriptions History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  const SizedBox(height: 12),
                  rxAsync.when(
                    data: (rxList) {
                      if (rxList.isEmpty) return const Text('No prescriptions yet.', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter'));
                      return Column(children: rxList.take(5).map((rx) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('Dr. ${rx.doctorName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                            const Spacer(),
                            Text('${rx.issuedAt.day}/${rx.issuedAt.month}/${rx.issuedAt.year}', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                          ]),
                          if (rx.diagnosis != null) Text(rx.diagnosis!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                          const SizedBox(height: 6),
                          ...rx.medicines.map((m) => Text('  - ${m.name} ${m.dosage} (${m.frequency})', style: const TextStyle(fontSize: 12, fontFamily: 'Inter'))),
                        ]),
                      )).toList());
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // Write prescription button
              userAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GradientButton(
                      label: 'Write Prescription',
                      colors: [AppColors.doctorPrimary, const Color(0xFF5B21B6)],
                      onPressed: () => _showPrescribeSheet(context, patientId, user.uid, user.name),
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _showPrescribeSheet(BuildContext context, String patientId, String doctorId, String doctorName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PrescribeSheet(patientId: patientId, doctorId: doctorId, doctorName: doctorName),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
  ]);
}

// ─── Write Prescription Sheet ─────────────────────────────────────────────────
class _PrescribeSheet extends ConsumerStatefulWidget {
  final String patientId, doctorId, doctorName;
  const _PrescribeSheet({required this.patientId, required this.doctorId, required this.doctorName});
  @override
  ConsumerState<_PrescribeSheet> createState() => _PrescribeSheetState();
}

class _PrescribeSheetState extends ConsumerState<_PrescribeSheet> {
  final _diagCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_MedEntry> _meds = [_MedEntry()];

  @override
  void dispose() { _diagCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  void _addMed() => setState(() => _meds.add(_MedEntry()));
  void _removeMed(int i) { if (_meds.length > 1) setState(() => _meds.removeAt(i)); }

  void _save() async {
    final medicines = _meds.where((m) => m.nameCtrl.text.isNotEmpty).map((m) => PrescribedMed(
      name: m.nameCtrl.text.trim(),
      dosage: m.dosageCtrl.text.trim(),
      frequency: m.frequency,
      instructions: m.instructionsCtrl.text.trim().isEmpty ? null : m.instructionsCtrl.text.trim(),
    )).toList();

    if (medicines.isEmpty) return;

    await ref.read(prescriptionNotifierProvider.notifier).add(
      patientId: widget.patientId,
      doctorId: widget.doctorId,
      doctorName: widget.doctorName,
      medicines: medicines,
      diagnosis: _diagCtrl.text.trim().isEmpty ? null : _diagCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      showAppSnack(context, 'Prescription saved with ${medicines.length} medicines');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Write Prescription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            const SizedBox(height: 20),

            TextField(controller: _diagCtrl, decoration: const InputDecoration(labelText: 'Diagnosis', hintText: 'e.g. Type 2 Diabetes')),
            const SizedBox(height: 16),

            // Medicines list
            Row(children: [
              const Text('Medicines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              const Spacer(),
              TextButton.icon(onPressed: _addMed, icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add')),
            ]),
            ...List.generate(_meds.length, (i) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextField(controller: _meds[i].nameCtrl, decoration: const InputDecoration(labelText: 'Medicine', filled: false))),
                  if (_meds.length > 1)
                    IconButton(icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.destructive), onPressed: () => _removeMed(i)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _meds[i].dosageCtrl, decoration: const InputDecoration(labelText: 'Dosage', hintText: '500mg', filled: false))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _meds[i].frequency,
                      decoration: const InputDecoration(labelText: 'Frequency', filled: false),
                      items: [AppConstants.freqOnce, AppConstants.freqTwice, AppConstants.freqThrice, AppConstants.freqAsNeeded]
                          .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12, fontFamily: 'Inter'))))
                          .toList(),
                      onChanged: (v) => _meds[i].frequency = v ?? AppConstants.freqOnce,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(controller: _meds[i].instructionsCtrl, decoration: const InputDecoration(labelText: 'Instructions (optional)', hintText: 'After meals', filled: false)),
              ]),
            )),

            const SizedBox(height: 12),
            TextField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Additional Notes (optional)')),
            const SizedBox(height: 20),
            GradientButton(label: 'Save Prescription', colors: [AppColors.doctorPrimary, const Color(0xFF5B21B6)], onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _MedEntry {
  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  String frequency = AppConstants.freqOnce;
  final instructionsCtrl = TextEditingController();
}
