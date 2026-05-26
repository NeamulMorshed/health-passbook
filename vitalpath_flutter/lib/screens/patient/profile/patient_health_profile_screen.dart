import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/appointment.dart';
import '../../../models/vital_reading.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/vitals_provider.dart';

class PatientHealthProfileScreen extends ConsumerWidget {
  const PatientHealthProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.',
        ),
      ),
      data: (user) {
        if (user == null) return const Scaffold(body: SizedBox.shrink());
        return _HealthProfileContent(uid: user.uid);
      },
    );
  }
}

class _HealthProfileContent extends ConsumerWidget {
  final String uid;
  const _HealthProfileContent({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientProfileProvider(uid));
    final medsAsync = ref.watch(medicinesProvider(uid));
    final vitalsAsync = ref.watch(vitalsProvider(uid));
    final apptsAsync =
        ref.watch(patientAppointmentsProvider((patientId: uid, limit: 5)));
    final rxAsync = ref.watch(patientPrescriptionsProvider((patientId: uid, limit: 5)));

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Health Profile'),
        actions: [
          IconButton(
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                color: AppColors.textPrimary,
                size: 20),
            tooltip: 'Edit health info',
            onPressed: () => context.push('/onboarding/health-profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(patientProfileProvider(uid));
          ref.invalidate(medicinesProvider(uid));
          ref.invalidate(vitalsProvider(uid));
          ref.invalidate(
              patientAppointmentsProvider((patientId: uid, limit: 5)));
          ref.invalidate(patientPrescriptionsProvider((patientId: uid, limit: 5)));
        },
        child: patientAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load health profile',
            subtitle: 'Pull to refresh.',
          ),
          data: (patient) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // ── Basic Health Stats ────────────────────────────────────────
              _SectionHeader(
                  'Basic Health Info',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedHeartCheck,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              if (patient == null)
                _EmptyInfo(
                    'No health info on record. Tap the edit button to add.')
              else ...[
                Row(children: [
                  Expanded(
                      child: _StatTile(
                          label: 'Blood Type',
                          value: patient.bloodType ?? '--',
                          color: AppColors.destructive,
                          bgColor: AppColors.destructiveLight)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatTile(
                          label: 'Weight',
                          value: patient.weight != null
                              ? '${patient.weight!.toStringAsFixed(0)} kg'
                              : '--',
                          color: AppColors.info,
                          bgColor: AppColors.infoLight)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatTile(
                          label: 'Height',
                          value: patient.height != null
                              ? '${patient.height!.toStringAsFixed(0)} cm'
                              : '--',
                          color: AppColors.success,
                          bgColor: AppColors.successLight)),
                ]),
                if (patient.bmi != null) ...[
                  const SizedBox(height: 10),
                  BentoCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      HugeIcon(
                          icon: HugeIcons.strokeRoundedChartIncrease,
                          color: AppColors.primary,
                          size: 18),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BMI  ${patient.bmi!.toStringAsFixed(1)}',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            Text(_bmiLabel(patient.bmi!),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _bmiColor(patient.bmi!))),
                          ]),
                    ]),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // ── Medical Conditions ────────────────────────────────────────
              _SectionHeader(
                  'Medical Conditions',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedMedicine01,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              if (patient == null || patient.conditions.isEmpty)
                _EmptyInfo('No conditions recorded.')
              else
                BentoCard(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: patient.conditions.map((c) => _Chip(c)).toList(),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Allergies ─────────────────────────────────────────────────
              _SectionHeader(
                  'Allergies',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedShield01,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              if (patient == null || patient.allergies.isEmpty)
                _EmptyInfo('No allergies recorded.')
              else
                BentoCard(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        patient.allergies.map((a) => _Chip(a)).toList(),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Emergency Contact ─────────────────────────────────────────
              _SectionHeader(
                  'Emergency Contact',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedCall,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              if (patient?.emergencyContact == null ||
                  (patient!.emergencyContact!.name.isEmpty &&
                      patient.emergencyContact!.phone.isEmpty))
                _EmptyInfo('No emergency contact added.')
              else
                BentoCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.destructive.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCall,
                              color: AppColors.destructive,
                              size: 18)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient.emergencyContact!.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          if (patient.emergencyContact!.phone.isNotEmpty ||
                              patient.emergencyContact!.relationship.isNotEmpty)
                            Text(
                              [
                                if (patient.emergencyContact!.relationship
                                    .isNotEmpty)
                                  patient.emergencyContact!.relationship,
                                if (patient.emergencyContact!.phone.isNotEmpty)
                                  patient.emergencyContact!.phone,
                              ].join(' · '),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedForeground),
                            ),
                        ]),
                  ]),
                ),

              const SizedBox(height: 24),

              // ── Latest Vitals ─────────────────────────────────────────────
              _SectionHeader(
                  'Latest Vitals',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedActivity01,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              vitalsAsync.when(
                loading: () => const _Shimmer(),
                error: (_, __) => _EmptyInfo('Could not load vitals.'),
                data: (readings) {
                  final latest = _latestByType(readings);
                  if (latest.isEmpty)
                    return _EmptyInfo('No vitals recorded yet.');
                  return Column(
                    children: latest.entries.map((e) {
                      final isNormal = VitalType.isNormal(e.key, e.value.value);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BentoCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(VitalType.labelFor(e.key),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.mutedForeground)),
                                    Text(
                                      '${e.value.value.truncateToDouble() == e.value.value ? e.value.value.toInt() : e.value.value.toStringAsFixed(1)} ${e.value.unit}',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isNormal
                                              ? AppColors.foreground
                                              : AppColors.destructive),
                                    ),
                                  ]),
                            ),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isNormal
                                              ? AppColors.success
                                              : AppColors.destructive)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isNormal ? 'Normal' : 'Out of range',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isNormal
                                              ? AppColors.success
                                              : AppColors.destructive),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM d')
                                        .format(e.value.recordedAt),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.mutedForeground),
                                  ),
                                ]),
                          ]),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Current Medications ───────────────────────────────────────
              _SectionHeader(
                  'Current Medications',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedMedicine01,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              medsAsync.when(
                loading: () => const _Shimmer(),
                error: (_, __) => _EmptyInfo('Could not load medications.'),
                data: (meds) {
                  if (meds.isEmpty) return _EmptyInfo('No medications added.');
                  return BentoCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: meds.asMap().entries.map((e) {
                        final m = e.value;
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                    child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedMedicine01,
                                        color: AppColors.primary,
                                        size: 16)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(m.name,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    Text('${m.dosage} · ${m.frequency}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.mutedForeground)),
                                  ])),
                            ]),
                          ),
                          if (e.key < meds.length - 1)
                            const Divider(
                                height: 1, indent: 62, color: AppColors.border),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Upcoming Appointments ─────────────────────────────────────
              _SectionHeader(
                  'Appointments',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              apptsAsync.when(
                loading: () => const _Shimmer(),
                error: (_, __) => _EmptyInfo('Could not load appointments.'),
                data: (appts) {
                  final upcoming = appts.where((a) => !a.isCancelled).toList()
                    ..sort((a, b) => (b.scheduledAt ?? DateTime(2000))
                        .compareTo(a.scheduledAt ?? DateTime(2000)));
                  if (upcoming.isEmpty)
                    return _EmptyInfo('No appointments found.');
                  return BentoCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children:
                          upcoming.take(5).toList().asMap().entries.map((e) {
                        final a = e.value;
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _apptStatusColor(a)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                    child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedCalendar01,
                                        color: _apptStatusColor(a),
                                        size: 16)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('Dr. ${a.doctorName}',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    if (a.scheduledAt != null)
                                      Text(
                                          DateFormat('EEE, MMM d · h:mm a')
                                              .format(a.scheduledAt!),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.mutedForeground)),
                                  ])),
                              _ApptStatusChip(a),
                            ]),
                          ),
                          if (e.key < upcoming.take(5).length - 1)
                            const Divider(
                                height: 1, indent: 62, color: AppColors.border),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Recent Prescriptions ──────────────────────────────────────
              _SectionHeader(
                  'Prescriptions',
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedNote,
                      color: AppColors.primary,
                      size: 16)),
              const SizedBox(height: 10),
              rxAsync.when(
                loading: () => const _Shimmer(),
                error: (_, __) => _EmptyInfo('Could not load prescriptions.'),
                data: (rxList) {
                  if (rxList.isEmpty)
                    return _EmptyInfo('No prescriptions found.');
                  final sorted = [...rxList]
                    ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
                  return BentoCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children:
                          sorted.take(3).toList().asMap().entries.map((e) {
                        final rx = e.value;
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                    child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedNote,
                                        color: AppColors.success,
                                        size: 16)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        rx.diagnosis?.isNotEmpty == true
                                            ? rx.diagnosis!
                                            : 'Prescription',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${rx.medicines.length} medication${rx.medicines.length == 1 ? '' : 's'} · ${DateFormat('MMM d, yyyy').format(rx.issuedAt)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.mutedForeground)),
                                  ])),
                            ]),
                          ),
                          if (e.key < sorted.take(3).length - 1)
                            const Divider(
                                height: 1, indent: 62, color: AppColors.border),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, VitalReading> _latestByType(List<VitalReading> all) {
    final map = <String, VitalReading>{};
    for (final r in all) {
      if (!map.containsKey(r.type) ||
          r.recordedAt.isAfter(map[r.type]!.recordedAt)) {
        map[r.type] = r;
      }
    }
    return map;
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.info;
    if (bmi < 25) return AppColors.success;
    if (bmi < 30) return AppColors.warning;
    return AppColors.destructive;
  }

  Color _apptStatusColor(Appointment a) {
    if (a.isConfirmed) return AppColors.success;
    if (a.isCompleted) return AppColors.mutedForeground;
    if (a.isCancelled) return AppColors.destructive;
    return AppColors.warning;
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) => Row(children: [
        icon,
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground)),
      ]);
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.color,
      required this.bgColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.mutedForeground)),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500)),
      );
}

class _EmptyInfo extends StatelessWidget {
  final String message;
  const _EmptyInfo(this.message);

  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(14),
        child: Text(message,
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
      );
}

class _ApptStatusChip extends StatelessWidget {
  final Appointment appt;
  const _ApptStatusChip(this.appt);

  @override
  Widget build(BuildContext context) {
    final (label, color) = appt.isConfirmed
        ? ('Confirmed', AppColors.success)
        : appt.isCompleted
            ? ('Done', AppColors.mutedForeground)
            : appt.isCancelled
                ? ('Cancelled', AppColors.destructive)
                : ('Pending', AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          for (int i = 0; i < 2; i++) ...[
            Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(4))),
            if (i == 0) const SizedBox(height: 8),
          ],
        ]),
      );
}
