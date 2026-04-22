import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/doctor.dart';
import '../../../models/prescription.dart';

class MyDoctorsScreen extends ConsumerWidget {
  const MyDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Doctors')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (context.mounted) context.go('/user-select'); },
            );
            return const Center(child: SizedBox.shrink());
          }

          final rxAsync = ref.watch(patientPrescriptionsProvider(user.uid));
          final searchAsync = ref.watch(doctorSearchProvider(''));

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: AppColors.surface,
                  child: const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.mutedForeground,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'My Doctors'),
                      Tab(text: 'Prescriptions'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DoctorsTab(searchAsync: searchAsync, uid: user.uid),
                      _PrescriptionsTab(rxAsync: rxAsync),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DoctorsTab extends ConsumerWidget {
  final AsyncValue<List<DoctorProfile>> searchAsync;
  final String uid;
  const _DoctorsTab({required this.searchAsync, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (doctors) {
        if (doctors.isEmpty) {
          return EmptyState(
            icon: Icons.person_search_rounded,
            title: 'No Doctors Found',
            subtitle: 'Book an appointment to connect with a doctor.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: doctors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _DoctorCard(doctor: doctors[i], patientId: uid),
        );
      },
    );
  }
}

class _DoctorCard extends ConsumerWidget {
  final DoctorProfile doctor;
  final String patientId;
  const _DoctorCard({required this.doctor, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            AppAvatar(name: doctor.name, imageUrl: doctor.photoUrl, size: 50, backgroundColor: AppColors.doctorPrimary),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Dr. ${doctor.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
                if (doctor.isVerified) const Icon(Icons.verified_rounded, color: AppColors.primary, size: 18),
              ]),
              if (doctor.specialty != null)
                Text(doctor.specialty!, style: const TextStyle(fontSize: 13, color: AppColors.doctorPrimary, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              if (doctor.hospital != null)
                Text(doctor.hospital!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ])),
            Column(children: [
              Row(children: [
                const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                const SizedBox(width: 2),
                Text(doctor.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ]),
              Text('${doctor.reviewCount} reviews', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ]),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showBookSheet(context, ref, doctor),
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: const Text('Book Appointment'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: AppColors.doctorPrimary,
                  side: const BorderSide(color: AppColors.doctorPrimary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Message'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ]),
        ],
      ),
    );
  }

  void _showBookSheet(BuildContext context, WidgetRef ref, DoctorProfile doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookAppointmentSheet(doctor: doctor, patientId: patientId),
    );
  }
}

class _BookAppointmentSheet extends ConsumerStatefulWidget {
  final DoctorProfile doctor;
  final String patientId;
  const _BookAppointmentSheet({required this.doctor, required this.patientId});
  @override
  ConsumerState<_BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends ConsumerState<_BookAppointmentSheet> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  void _book() async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await ref.read(appointmentNotifierProvider.notifier).book(
      patientId: user.uid,
      patientName: user.name,
      doctorId: widget.doctor.uid,
      doctorName: widget.doctor.name,
      doctorSpecialty: widget.doctor.specialty,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (mounted) {
      Navigator.pop(context);
      showAppSnack(context, 'Appointment request sent to Dr. ${widget.doctor.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Book with Dr. ${widget.doctor.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            if (widget.doctor.specialty != null) ...[
              const SizedBox(height: 4),
              Text(widget.doctor.specialty!, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason for visit (optional)', hintText: 'Describe your symptoms or concern...'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('The doctor will confirm the appointment date and time.', style: TextStyle(fontSize: 12, color: AppColors.warning, fontFamily: 'Inter'))),
              ]),
            ),
            const SizedBox(height: 20),
            GradientButton(label: 'Send Request', colors: [AppColors.doctorPrimary, const Color(0xFF5B21B6)], onPressed: _book),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionsTab extends StatelessWidget {
  final AsyncValue<List<Prescription>> rxAsync;
  const _PrescriptionsTab({required this.rxAsync});

  @override
  Widget build(BuildContext context) {
    return rxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (prescriptions) {
        if (prescriptions.isEmpty) {
          return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No Prescriptions', subtitle: 'Prescriptions from your doctors will appear here.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: prescriptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _PrescriptionCard(rx: prescriptions[i]),
        );
      },
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final Prescription rx;
  const _PrescriptionCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dr. ${rx.doctorName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            Text('${rx.issuedAt.day}/${rx.issuedAt.month}/${rx.issuedAt.year}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ])),
          StatusBadge.success('${rx.medicines.length} meds'),
        ]),
        if (rx.diagnosis != null) ...[
          const SizedBox(height: 10),
          Text('Diagnosis: ${rx.diagnosis}', style: const TextStyle(fontSize: 13, color: AppColors.foreground, fontFamily: 'Inter')),
        ],
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 8),
        ...rx.medicines.map((med) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.circle, size: 6, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('${med.name} - ${med.dosage}', style: const TextStyle(fontSize: 13, fontFamily: 'Inter'))),
            Text(med.frequency, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ]),
        )),
        if (rx.notes != null) ...[
          const SizedBox(height: 8),
          Text('Note: ${rx.notes}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontStyle: FontStyle.italic, fontFamily: 'Inter')),
        ],
      ]),
    );
  }
}
