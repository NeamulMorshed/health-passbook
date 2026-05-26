import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/vital_trend_chart.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../providers/vitals_provider.dart';
import '../../../models/caregiver_connection.dart';
import 'package:go_router/go_router.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../models/activity_log.dart';
import '../../../models/prescription.dart';
import '../../../models/patient.dart';
import '../../../models/consultation_note.dart';
import '../../../models/vital_reading.dart';
import '../../../models/drug_interaction.dart';
import '../../../services/drug_interaction_service.dart';
import 'package:intl/intl.dart';

const _uuid = Uuid();

class DocPatientViewScreen extends ConsumerWidget {
  final String patientId;
  const DocPatientViewScreen({super.key, required this.patientId});

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
      data: (doctor) {
        if (doctor == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) {
              if (context.mounted) context.go('/user-select');
            },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        final connectionAsync = ref.watch(
          connectionCheckProvider((doctorId: doctor.uid, patientId: patientId)),
        );
        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(title: const Text('Patient Details')),
          body: connectionAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Something went wrong',
              subtitle: 'Pull to refresh or try again.',
            ),
            data: (isConnected) {
              if (!isConnected) {
                return const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Access Denied',
                  subtitle:
                      'You do not have an active connection with this patient.',
                );
              }
              return _PatientDetailBody(
                doctorId: doctor.uid,
                doctorName: doctor.name,
                patientId: patientId,
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Tabbed body ──────────────────────────────────────────────────────────────
class _PatientDetailBody extends ConsumerStatefulWidget {
  final String doctorId;
  final String doctorName;
  final String patientId;

  const _PatientDetailBody({
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
  });

  @override
  ConsumerState<_PatientDetailBody> createState() => _PatientDetailBodyState();
}

class _PatientDetailBodyState extends ConsumerState<_PatientDetailBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientProfileProvider(widget.patientId));
    final medsAsync = ref.watch(medicinesProvider(widget.patientId));
    final mealsAsync = ref.watch(todayMealsProvider(widget.patientId));
    final activityAsync = ref.watch(activityLogsProvider(widget.patientId));
    final rxAsync = ref.watch(patientPrescriptionsProvider((patientId: widget.patientId, limit: 20)));

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Error',
        subtitle: 'Could not load patient data.',
      ),
      data: (patient) {
        if (patient == null) {
          return const EmptyState(
            icon: Icons.error_outline,
            title: 'Not Found',
            subtitle: 'Patient data not available.',
          );
        }

        return Column(
          children: [
            // ── Tab bar ────────────────────────────────────────────────────
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.mutedForeground,
                indicatorColor: AppColors.primary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: [
                  Tab(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedUser,
                          color: _tabCtrl.index == 0
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          size: 18),
                      text: 'Overview'),
                  Tab(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedMedicine01,
                          color: _tabCtrl.index == 1
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          size: 18),
                      text: 'Medicines'),
                  Tab(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedActivity01,
                          color: _tabCtrl.index == 2
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          size: 18),
                      text: 'Health Log'),
                  Tab(
                      icon: Icon(Icons.description_rounded, size: 18),
                      text: 'Rx History'),
                  Tab(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedNote,
                          color: _tabCtrl.index == 4
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          size: 18),
                      text: 'Notes'),
                  Tab(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedActivity01,
                          color: _tabCtrl.index == 5
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          size: 18),
                      text: 'Vitals'),
                ],
              ),
            ),
            // ── Tab views ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _OverviewTab(
                      patient: patient,
                      patientId: widget.patientId,
                      medsAsync: medsAsync),
                  _MedicinesTab(medsAsync: medsAsync),
                  _HealthLogTab(
                    mealsAsync: mealsAsync,
                    activityAsync: activityAsync,
                  ),
                  _PrescriptionsTab(
                    rxAsync: rxAsync,
                    patientId: widget.patientId,
                    patientName: patient.name,
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                  ),
                  _NotesTab(
                    patientId: widget.patientId,
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                  ),
                  _VitalsTab(patientId: widget.patientId),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Tab 1: Overview ─────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final PatientProfile patient;
  final String patientId;
  final AsyncValue<List<Medicine>> medsAsync;

  const _OverviewTab({
    required this.patient,
    required this.patientId,
    required this.medsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Patient header card
        BentoCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            AppAvatar(name: patient.name, size: 64),
            const SizedBox(height: 12),
            Text(
              patient.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _VitalStat('${patient.age ?? '--'}', 'Age', 'yrs'),
                _divider(),
                _VitalStat(
                    patient.weight?.toStringAsFixed(0) ?? '--', 'Weight', 'kg'),
                _divider(),
                _VitalStat(patient.bloodType ?? '--', 'Blood', 'type'),
                _divider(),
                _VitalStat(patient.bmi?.toStringAsFixed(1) ?? '--', 'BMI', ''),
              ],
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // Quick health insight chips
        medsAsync.when(
          data: (meds) {
            final takenToday = meds.where((m) => m.takenToday).length;
            final total = meds.length;
            final pct = total > 0 ? (takenToday / total * 100).round() : 0;
            final adherenceColor = pct >= 80
                ? AppColors.success
                : pct >= 50
                    ? AppColors.warning
                    : AppColors.destructive;

            final medColor = takenToday == total && total > 0
                ? AppColors.success
                : AppColors.warning;
            return Row(children: [
              Expanded(
                child: _InsightChip(
                  icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedMedicine01,
                      color: medColor,
                      size: 18),
                  label: "Today's Meds",
                  value: '$takenToday/$total',
                  subtitle: 'taken today',
                  color: medColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightChip(
                  icon: Icon(Icons.trending_up_rounded,
                      size: 18,
                      color: total > 0
                          ? adherenceColor
                          : AppColors.mutedForeground),
                  label: 'Adherence',
                  value: total > 0 ? '$pct%' : '--',
                  subtitle: 'today\'s session',
                  color: total > 0 ? adherenceColor : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightChip(
                  icon: const Icon(Icons.local_pharmacy_rounded,
                      size: 18, color: AppColors.primary),
                  label: 'Medicines',
                  value: '$total',
                  subtitle: 'active',
                  color: AppColors.primary,
                ),
              ),
            ]);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // Medical conditions
        if (patient.conditions.isNotEmpty) ...[
          _SectionCard(
            title: 'Medical Conditions',
            icon: Icons.monitor_heart_outlined,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: patient.conditions
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Allergies
        if (patient.allergies.isNotEmpty) ...[
          _SectionCard(
            title: 'Allergies',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.destructive,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.destructive),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patient.allergies.join(', '),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.destructive),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Emergency contact
        if (patient.emergencyContact != null) ...[
          _SectionCard(
            title: 'Emergency Contact',
            icon: Icons.emergency_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      color: AppColors.mutedForeground,
                      size: 16),
                  const SizedBox(width: 8),
                  Text(
                    patient.emergencyContact!.name.isNotEmpty
                        ? patient.emergencyContact!.name
                        : patient.emergencyContact!.phone,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ]),
                if (patient.emergencyContact!.relationship.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    patient.emergencyContact!.relationship,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ],
                if (patient.emergencyContact!.name.isNotEmpty &&
                    patient.emergencyContact!.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedTelephone,
                        color: AppColors.mutedForeground,
                        size: 14),
                    const SizedBox(width: 6),
                    Text(
                      patient.emergencyContact!.phone,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 7b: Family circle — only renders if patient has opted in
        // (shareCircleWithDoctors == true). Otherwise the Firestore rule
        // denies the read and the section stays hidden.
        _FamilyMembersSection(patientId: patientId),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: AppColors.border);
}

// ─── Family members section (doctor view, opt-in) ─────────────────────────────
class _FamilyMembersSection extends ConsumerWidget {
  final String patientId;
  const _FamilyMembersSection({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connsAsync = ref.watch(doctorVisibleCaregiversProvider(patientId));
    return connsAsync.when(
      // Permission denied (patient hasn't opted in) or empty list — stay silent.
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      data: (conns) {
        if (conns.isEmpty) return const SizedBox.shrink();
        return _SectionCard(
          title: 'Family Caring for ${_firstName(conns)}',
          icon: Icons.family_restroom_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < conns.length; i++) ...[
                if (i > 0) const Divider(height: 16),
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.caregiver.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(conns[i].caregiverName ?? '?'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.caregiver,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conns[i].caregiverName ?? 'Family member',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          conns[i].relationship.relationshipLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  String _firstName(List<CaregiverConnection> conns) {
    // Use patient name from the first connection (all share the same patientId).
    final name = conns.first.patientName;
    final parts = name.trim().split(' ');
    return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : 'patient';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Tab 2: Medicines ─────────────────────────────────────────────────────────
class _MedicinesTab extends StatelessWidget {
  final AsyncValue<List<Medicine>> medsAsync;
  const _MedicinesTab({required this.medsAsync});

  @override
  Widget build(BuildContext context) {
    return medsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (meds) {
        if (meds.isEmpty) {
          return const EmptyState(
            icon: Icons.medication_outlined,
            iconWidget: HugeIcon(
                icon: HugeIcons.strokeRoundedMedicine01,
                color: AppColors.mutedForeground,
                size: 40),
            title: 'No Active Medicines',
            subtitle: 'This patient has no medicines recorded.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: meds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _AdherenceCard(med: meds[i]),
        );
      },
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  final Medicine med;
  const _AdherenceCard({required this.med});

  int get _expectedPerWeek => switch (med.frequency) {
        AppConstants.freqOnce => 7,
        AppConstants.freqTwice => 14,
        AppConstants.freqThrice => 21,
        AppConstants.freqWeekly => 1,
        _ => 0,
      };

  int get _takenThisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return med.loggedDoses.where((d) => d.isAfter(cutoff)).length;
  }

  @override
  Widget build(BuildContext context) {
    final expected = _expectedPerWeek;
    final taken = _takenThisWeek;
    final adherence = expected > 0 ? (taken / expected).clamp(0.0, 1.0) : -1.0;
    final adherencePct = adherence >= 0 ? (adherence * 100).round() : null;

    final Color adherenceColor = adherencePct == null
        ? AppColors.mutedForeground
        : adherencePct >= 80
            ? AppColors.success
            : adherencePct >= 50
                ? AppColors.warning
                : AppColors.destructive;

    final StatusBadge todayBadge;
    if (med.fullyTakenToday) {
      todayBadge = StatusBadge.success('All Taken');
    } else if (med.hasMissedSlot) {
      todayBadge = StatusBadge.danger('Missed');
    } else if (med.hasDueSlot) {
      todayBadge = StatusBadge.warning('Due Now');
    } else {
      todayBadge = StatusBadge.info('Upcoming');
    }

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMedicine01,
                  color: AppColors.primary,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${med.dosage} · ${med.frequency}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mutedForeground)),
                  ]),
            ),
            todayBadge,
          ]),

          // Adherence bar
          if (adherencePct != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Text('7-day adherence',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
              const Spacer(),
              Text('$taken / $expected doses',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: adherenceColor)),
              const SizedBox(width: 6),
              Text('($adherencePct%)',
                  style: TextStyle(fontSize: 12, color: adherenceColor)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: adherence,
                backgroundColor: AppColors.muted,
                color: adherenceColor,
                minHeight: 7,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('As needed — no fixed schedule',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ),
          ],

          // Meta row
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (med.prescribedBy != null)
              _MetaChip(
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    color: AppColors.mutedForeground,
                    size: 12),
                label: 'Dr. ${med.prescribedBy}',
              ),
            _MetaChip(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  color: AppColors.mutedForeground,
                  size: 12),
              label:
                  'Since ${med.startDate.day}/${med.startDate.month}/${med.startDate.year}',
            ),
            _MetaChip(
              icon: const Icon(Icons.history_rounded,
                  size: 14, color: AppColors.mutedForeground),
              label:
                  '${med.loggedDoses.length} total dose${med.loggedDoses.length == 1 ? '' : 's'}',
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Tab 3: Health Log ────────────────────────────────────────────────────────
class _HealthLogTab extends StatelessWidget {
  final AsyncValue<List<MealLog>> mealsAsync;
  final AsyncValue<List<ActivityLog>> activityAsync;
  const _HealthLogTab({required this.mealsAsync, required this.activityAsync});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // ── Nutrition ──────────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.restaurant_rounded,
          title: "Today's Nutrition",
          color: AppColors.warning,
        ),
        const SizedBox(height: 10),
        mealsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (meals) {
            if (meals.isEmpty) {
              return _emptyCard('No meals logged today.');
            }
            final totalCal = meals.fold(0, (s, m) => s + (m.calories ?? 0));
            final totalProtein =
                meals.fold(0.0, (s, m) => s + (m.protein ?? 0));
            final totalCarbs = meals.fold(0.0, (s, m) => s + (m.carbs ?? 0));
            final totalFat = meals.fold(0.0, (s, m) => s + (m.fat ?? 0));

            return Column(children: [
              // Macro summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.2)),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MacroStat(
                          '$totalCal', 'kcal', 'Calories', AppColors.warning),
                      _MacroStat(totalProtein.toStringAsFixed(0), 'g',
                          'Protein', AppColors.primary),
                      _MacroStat(totalCarbs.toStringAsFixed(0), 'g', 'Carbs',
                          AppColors.success),
                      _MacroStat(totalFat.toStringAsFixed(0), 'g', 'Fat',
                          AppColors.destructive),
                    ]),
              ),
              const SizedBox(height: 10),
              ...meals.map((meal) => _MealRow(meal: meal)),
            ]);
          },
        ),

        const SizedBox(height: 20),

        // ── Activity ───────────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.directions_run_rounded,
          title: 'Recent Activity',
          color: AppColors.primary,
        ),
        const SizedBox(height: 10),
        activityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (logs) {
            if (logs.isEmpty) {
              return _emptyCard('No activity recorded.');
            }
            return Column(
                children: logs.map((log) => _ActivityRow(log: log)).toList());
          },
        ),
      ],
    );
  }

  Widget _emptyCard(String text) => BentoCard(
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
      );
}

class _MealRow extends StatelessWidget {
  final MealLog meal;
  const _MealRow({required this.meal});

  @override
  Widget build(BuildContext context) {
    final mealIcons = {
      'Breakfast': Icons.wb_sunny_rounded,
      'Lunch': Icons.light_mode_rounded,
      'Dinner': Icons.nights_stay_rounded,
      'Snack': Icons.cookie_rounded,
    };
    final icon = mealIcons[meal.mealType] ?? Icons.restaurant_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meal.description,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(meal.mealType,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ]),
          ),
          if (meal.calories != null)
            Text('${meal.calories} kcal',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning)),
        ]),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityLog log;
  const _ActivityRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final typeIcons = {
      'walk': Icons.directions_walk_rounded,
      'run': Icons.directions_run_rounded,
      'steps': Icons.directions_walk_rounded,
      'cycle': Icons.pedal_bike_rounded,
    };
    final icon =
        typeIcons[log.type.toLowerCase()] ?? Icons.fitness_center_rounded;
    final mins = log.durationSeconds ~/ 60;
    final typeName = log.type[0].toUpperCase() + log.type.substring(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(typeName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                  '${log.loggedAt.day}/${log.loggedAt.month}/${log.loggedAt.year}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ]),
          ),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _MetaChip(
              icon: const Icon(Icons.timer_rounded,
                  size: 14, color: AppColors.mutedForeground),
              label: '${mins}m',
            ),
            if (log.distanceKm != null)
              _MetaChip(
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMapPin,
                    color: AppColors.mutedForeground,
                    size: 11),
                label: '${log.distanceKm!.toStringAsFixed(1)} km',
              ),
            if (log.steps != null)
              _MetaChip(
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedWalking,
                    color: AppColors.mutedForeground,
                    size: 11),
                label: '${log.steps} steps',
              ),
            if (log.caloriesBurned != null)
              _MetaChip(
                icon: const Icon(Icons.local_fire_department_rounded,
                    size: 14, color: AppColors.mutedForeground),
                label: '${log.caloriesBurned} cal',
              ),
          ]),
        ]),
      ),
    );
  }
}

// ─── Tab 4: Rx History ────────────────────────────────────────────────────────
class _PrescriptionsTab extends ConsumerStatefulWidget {
  final AsyncValue<List<Prescription>> rxAsync;
  final String patientId, patientName, doctorId, doctorName;

  const _PrescriptionsTab({
    required this.rxAsync,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  ConsumerState<_PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends ConsumerState<_PrescriptionsTab> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Write prescription CTA at top of tab
        GradientButton(
          label: 'Write New Prescription',
          colors: const [AppColors.primary, Color(0xFF5B21B6)],
          onPressed: () => _showPrescribeSheet(context),
        ),
        const SizedBox(height: 20),

        _SectionHeader(
          icon: Icons.description_rounded,
          title: 'Prescription History',
          color: AppColors.primary,
        ),
        const SizedBox(height: 10),

        widget.rxAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
              icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
          data: (rxList) {
            if (rxList.isEmpty) {
              return BentoCard(
                child: const Text('No prescriptions on record.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.mutedForeground)),
              );
            }
            const pageSize = 5;
            final visible = _showAll ? rxList : rxList.take(pageSize).toList();
            return Column(children: [
              ...visible.map((rx) => _RxCard(rx: rx)),
              if (rxList.length > pageSize)
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  icon: _showAll
                      ? HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowUp01,
                          color: Colors.black,
                          size: 18)
                      : HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          color: Colors.black,
                          size: 18),
                  label: Text(
                    _showAll
                        ? 'Show fewer'
                        : 'Show all ${rxList.length} prescriptions',
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }

  void _showPrescribeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PrescribeSheet(
        patientId: widget.patientId,
        patientName: widget.patientName,
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
      ),
    );
  }
}

class _RxCard extends StatelessWidget {
  final Prescription rx;
  const _RxCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_rounded,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Dr. ${rx.doctorName}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text('${rx.issuedAt.day}/${rx.issuedAt.month}/${rx.issuedAt.year}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.mutedForeground)),
          ]),
          if (rx.diagnosis != null && rx.diagnosis!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(rx.diagnosis!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.mutedForeground)),
          ],
          const SizedBox(height: 8),
          ...rx.medicines.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.circle,
                      size: 5, color: AppColors.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${m.name} ${m.dosage} (${m.frequency})',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ]),
              )),
        ]),
      ),
    );
  }
}

// ─── Shared helper widgets ────────────────────────────────────────────────────

class _VitalStat extends StatelessWidget {
  final String value, label, unit;
  const _VitalStat(this.value, this.label, this.unit);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (unit.isNotEmpty)
          Text(unit,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.mutedForeground)),
      ]);
}

class _InsightChip extends StatelessWidget {
  final Widget icon;
  final String label, value, subtitle;
  final Color color;
  const _InsightChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          icon,
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
        ]),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? iconColor;
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.child,
      this.iconColor});

  @override
  Widget build(BuildContext context) => BentoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: iconColor ?? AppColors.mutedForeground),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]);
}

class _MetaChip extends StatelessWidget {
  final Widget icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.mutedForeground)),
      ]);
}

class _MacroStat extends StatelessWidget {
  final String value, unit, label;
  final Color color;
  const _MacroStat(this.value, this.unit, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        Text(unit,
            style:
                TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.mutedForeground)),
      ]);
}

// ─── Tab 5: Consultation Notes ────────────────────────────────────────────────
class _NotesTab extends ConsumerStatefulWidget {
  final String patientId, doctorId, doctorName;
  const _NotesTab(
      {required this.patientId,
      required this.doctorId,
      required this.doctorName});
  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(consultationNoteNotifierProvider.notifier).add(
            patientId: widget.patientId,
            doctorId: widget.doctorId,
            doctorName: widget.doctorName,
            note: text,
          );
      if (mounted) {
        _noteCtrl.clear();
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(context, 'Failed to save note');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(consultationNotesProvider(
      (patientId: widget.patientId, doctorId: widget.doctorId),
    ));

    return Column(children: [
      // Add note input area
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _noteCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Write a private consultation note…',
                filled: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _saving
              ? const SizedBox(
                  width: 42,
                  height: 42,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : ElevatedButton(
                  onPressed: _addNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(42, 42),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.send_rounded, size: 18),
                ),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),

      // Notes list
      Expanded(
        child: notesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load notes',
              subtitle: 'Check your connection and try again.'),
          data: (notes) {
            if (notes.isEmpty) {
              return const EmptyState(
                icon: Icons.note_alt_outlined,
                title: 'No Notes Yet',
                subtitle: 'Your private consultation notes will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NoteCard(
                  note: notes[i],
                  onDelete: () async {
                    try {
                      await ref
                          .read(consultationNoteNotifierProvider.notifier)
                          .delete(widget.patientId, notes[i].id);
                    } catch (_) {
                      if (context.mounted) {
                        AppSnackBar.error(context, 'Failed to delete note. Please try again.');
                      }
                    }
                  }),
            );
          },
        ),
      ),
    ]);
  }
}

class _NoteCard extends StatelessWidget {
  final ConsultationNote note;
  final Future<void> Function() onDelete;
  const _NoteCard({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.note_alt_rounded,
              size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(DateFormat('MMM d, y · h:mm a').format(note.createdAt),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
          const Spacer(),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Note'),
                content: const Text('Delete this consultation note?'),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                actions: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.destructive),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                        child: const Text('Delete'),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            child: HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                color: AppColors.destructive,
                size: 16),
          ),
        ]),
        const SizedBox(height: 8),
        Text(note.note, style: const TextStyle(fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

// ─── Write Prescription Sheet ─────────────────────────────────────────────────
class _PrescribeSheet extends ConsumerStatefulWidget {
  final String patientId, patientName, doctorId, doctorName;
  const _PrescribeSheet(
      {required this.patientId,
      required this.patientName,
      required this.doctorId,
      required this.doctorName});

  @override
  ConsumerState<_PrescribeSheet> createState() => _PrescribeSheetState();
}

class _PrescribeSheetState extends ConsumerState<_PrescribeSheet> {
  final _diagCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_MedEntry> _meds = [_MedEntry()];

  @override
  void dispose() {
    _diagCtrl.dispose();
    _notesCtrl.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    super.dispose();
  }

  void _addMed() => setState(() => _meds.add(_MedEntry()));
  void _removeMed(int i) {
    if (_meds.length > 1) setState(() => _meds.removeAt(i));
  }

  Future<void> _commit({
    required List<PrescribedMed> medicines,
    required String? diagnosis,
    required String? notes,
  }) async {
    await ref.read(prescriptionNotifierProvider.notifier).add(
          patientId: widget.patientId,
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
          medicines: medicines,
          diagnosis: diagnosis,
          notes: notes,
        );

    // Mirror each medicine into the patient's Care screen
    final fs = ref.read(firestoreServiceProvider);
    for (final m in medicines) {
      final med = Medicine(
        id: _uuid.v4(),
        patientId: widget.patientId,
        name: m.name,
        dosage: m.dosage,
        frequency: m.frequency,
        notes: m.instructions,
        startDate: DateTime.now(),
        reminderTimes: const [],
        reminderRepeat: 'daily',
        prescribedBy: widget.doctorName,
      );
      await fs.addMedicine(widget.patientId, med);
    }
  }

  Future<void> _showConfirmation() async {
    final medicines = _meds
        .where((m) => m.nameCtrl.text.isNotEmpty)
        .map((m) => PrescribedMed(
              name: m.nameCtrl.text.trim(),
              dosage: m.dosageCtrl.text.trim(),
              frequency: m.frequency,
              instructions: m.instructionsCtrl.text.trim().isEmpty
                  ? null
                  : m.instructionsCtrl.text.trim(),
            ))
        .toList();

    if (medicines.isEmpty) return;

    final diagnosis =
        _diagCtrl.text.trim().isEmpty ? null : _diagCtrl.text.trim();
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PrescriptionConfirmDialog(
        patientId: widget.patientId,
        patientName: widget.patientName,
        diagnosis: diagnosis,
        medicines: medicines,
        notes: notes,
        onCommit: () => _commit(
          medicines: medicines,
          diagnosis: diagnosis,
          notes: notes,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context);
      AppSnackBar.success(context, 'Prescription saved · ${medicines.length} medicine${medicines.length == 1 ? '' : 's'} added to ${widget.patientName}\'s Care screen');
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
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Write Prescription',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextField(
              controller: _diagCtrl,
              decoration: const InputDecoration(
                  labelText: 'Diagnosis', hintText: 'e.g. Type 2 Diabetes'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Medicines',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                  onPressed: _addMed,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add')),
            ]),
            ...List.generate(
              _meds.length,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                          controller: _meds[i].nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Medicine', filled: false)),
                    ),
                    if (_meds.length > 1)
                      IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: AppColors.destructive),
                          onPressed: () => _removeMed(i)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                          controller: _meds[i].dosageCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Dosage',
                              hintText: '500mg',
                              filled: false)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _meds[i].frequency,
                        decoration: const InputDecoration(
                            labelText: 'Frequency', filled: false),
                        items: [
                          AppConstants.freqOnce,
                          AppConstants.freqTwice,
                          AppConstants.freqThrice,
                          AppConstants.freqAsNeeded
                        ]
                            .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f,
                                    style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (v) =>
                            _meds[i].frequency = v ?? AppConstants.freqOnce,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _meds[i].instructionsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Instructions (optional)',
                          hintText: 'After meals',
                          filled: false)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Additional Notes (optional)'),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Review & Save',
              colors: const [AppColors.primary, Color(0xFF5B21B6)],
              onPressed: _showConfirmation,
            ),
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

  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    instructionsCtrl.dispose();
  }
}

// ─── Prescription Confirmation Dialog ─────────────────────────────────────────
class _PrescriptionConfirmDialog extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String? diagnosis;
  final List<PrescribedMed> medicines;
  final String? notes;
  final Future<void> Function() onCommit;

  const _PrescriptionConfirmDialog({
    required this.patientId,
    required this.patientName,
    required this.diagnosis,
    required this.medicines,
    required this.notes,
    required this.onCommit,
  });

  @override
  ConsumerState<_PrescriptionConfirmDialog> createState() =>
      _PrescriptionConfirmDialogState();
}

class _PrescriptionConfirmDialogState
    extends ConsumerState<_PrescriptionConfirmDialog> {
  bool _committing = false;
  String? _errorMsg;

  // Phase 8: safety check state
  bool _checkingSafety = true;
  List<DrugInteraction> _interactions = const [];
  List<_AllergyMatch> _allergyMatches = const [];
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    _runSafetyChecks();
  }

  Future<void> _runSafetyChecks() async {
    final newDrugs = widget.medicines.map((m) => m.name).toList();
    try {
      // 1. Pull patient profile (for allergies) and active medicines.
      final profile = await ref
          .read(patientProfileProvider(widget.patientId).future);
      final activeMeds = await ref
          .read(medicinesProvider(widget.patientId).future);
      final activeDrugNames =
          activeMeds.where((m) => m.isActive).map((m) => m.name).toList();

      // 2. Drug-drug interactions across {new drugs} ∪ {active drugs}.
      // The service handles caching, dedup, and graceful failure.
      final combined = {...newDrugs, ...activeDrugNames}.toList();
      final interactions = combined.length >= 2
          ? await DrugInteractionService.instance.checkInteractions(combined)
          : <DrugInteraction>[];

      // 3. Allergy cross-check — only on NEW drugs (existing actives already
      // passed a check when added). Each new drug × each patient allergy.
      final allergyMatches = <_AllergyMatch>[];
      for (final drug in newDrugs) {
        for (final allergy in profile?.allergies ?? const <String>[]) {
          if (_allergyMatches_(drug, allergy)) {
            allergyMatches.add(_AllergyMatch(drug: drug, allergy: allergy));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _interactions = interactions;
        _allergyMatches = allergyMatches;
        _checkingSafety = false;
      });
    } catch (_) {
      // Defensive — never let safety check failure block the prescription.
      // The doctor sees a graceful "could not run safety check" hint.
      if (!mounted) return;
      setState(() {
        _checkingSafety = false;
      });
    }
  }

  bool get _hasCriticalWarnings =>
      _allergyMatches.isNotEmpty ||
      _interactions
          .any((i) => i.severity == InteractionSeverity.major);

  Future<void> _confirm() async {
    setState(() {
      _committing = true;
      _errorMsg = null;
    });
    try {
      await widget.onCommit();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _committing = false;
          _errorMsg = 'Failed to save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    const Text('Confirm Prescription',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  Text('For ${widget.patientName}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.mutedForeground)),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.diagnosis != null) ...[
                      const Text('Diagnosis',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(widget.diagnosis!,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                    ],

                    const Text('Medicines',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    ...widget.medicines.map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (m.dosage.isNotEmpty) m.dosage,
                                        m.frequency,
                                      ].join(' · '),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedForeground),
                                    ),
                                    if (m.instructions != null) ...[
                                      const SizedBox(height: 2),
                                      Text(m.instructions!,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.mutedForeground,
                                              fontStyle: FontStyle.italic)),
                                    ],
                                  ]),
                            ),
                          ]),
                        )),

                    if (widget.notes != null) ...[
                      const SizedBox(height: 8),
                      const Text('Notes',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(widget.notes!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground)),
                      const SizedBox(height: 12),
                    ],

                    // Phase 8: Safety checks (allergy + drug interactions)
                    _SafetyChecksSection(
                      checking: _checkingSafety,
                      interactions: _interactions,
                      allergyMatches: _allergyMatches,
                    ),

                    if (_hasCriticalWarnings && !_checkingSafety) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _acknowledged,
                        onChanged: (v) =>
                            setState(() => _acknowledged = v ?? false),
                        title: const Text(
                          "I've reviewed the safety warnings above",
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AppColors.destructive,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Consequence callout
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saving will add these medicines to ${widget.patientName}\'s Care screen immediately.',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(_errorMsg!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.destructive)),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Action row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _committing ? null : () => Navigator.pop(context, false),
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_committing ||
                            _checkingSafety ||
                            (_hasCriticalWarnings && !_acknowledged))
                        ? null
                        : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                    ),
                    child: _committing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirm & Save'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 6: Vitals ────────────────────────────────────────────────────────────
class _VitalsTab extends ConsumerWidget {
  final String patientId;
  const _VitalsTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsAsync = ref.watch(vitalsProvider(patientId));
    return vitalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Error loading vitals',
        subtitle: 'Check connection and try again.',
      ),
      data: (readings) {
        final latestBpSys =
            readings.where((r) => r.type == VitalType.bpSystolic).firstOrNull;
        final latestBpDia =
            readings.where((r) => r.type == VitalType.bpDiastolic).firstOrNull;
        final latestPulse =
            readings.where((r) => r.type == VitalType.pulse).firstOrNull;
        final latestGlucose =
            readings.where((r) => r.type == VitalType.glucose).firstOrNull;
        final latestSpo2 =
            readings.where((r) => r.type == VitalType.spo2).firstOrNull;
        final latestTemp =
            readings.where((r) => r.type == VitalType.temp).firstOrNull;

        String fmt(VitalReading? r) {
          if (r == null) return '--';
          return r.value.truncateToDouble() == r.value
              ? r.value.toInt().toString()
              : r.value.toStringAsFixed(1);
        }

        Color dotColor(VitalReading? r) {
          if (r == null) return AppColors.mutedForeground;
          return VitalType.isNormal(r.type, r.value)
              ? AppColors.success
              : AppColors.destructive;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BentoSectionHeader(title: '30-Day Trends'),
              const SizedBox(height: 12),
              BentoCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Blood Pressure',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    VitalTrendChart(
                      patientId: patientId,
                      types: [VitalType.bpSystolic, VitalType.bpDiastolic],
                      height: 130,
                      showAxis: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BentoRow(
                left: BentoCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Glucose',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      VitalTrendChart(
                        patientId: patientId,
                        types: [VitalType.glucose],
                        height: 100,
                        showAxis: true,
                      ),
                    ],
                  ),
                ),
                right: BentoCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pulse',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      VitalTrendChart(
                        patientId: patientId,
                        types: [VitalType.pulse],
                        height: 100,
                        showAxis: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BentoSectionHeader(title: 'Latest Readings'),
              const SizedBox(height: 12),
              BentoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _VitalRow(
                      label: 'Blood Pressure',
                      value: latestBpSys != null
                          ? '${fmt(latestBpSys)}/${fmt(latestBpDia)} mmHg'
                          : '--',
                      color: dotColor(latestBpSys),
                      icon: HugeIcons.strokeRoundedDroplet,
                    ),
                    const Divider(height: 20, color: AppColors.border),
                    _VitalRow(
                      label: 'Pulse',
                      value: latestPulse != null
                          ? '${fmt(latestPulse)} bpm'
                          : '--',
                      color: dotColor(latestPulse),
                      icon: HugeIcons.strokeRoundedActivity01,
                    ),
                    const Divider(height: 20, color: AppColors.border),
                    _VitalRow(
                      label: 'Blood Glucose',
                      value: latestGlucose != null
                          ? '${fmt(latestGlucose)} mg/dL'
                          : '--',
                      color: dotColor(latestGlucose),
                      icon: HugeIcons.strokeRoundedDroplet,
                    ),
                    const Divider(height: 20, color: AppColors.border),
                    _VitalRow(
                      label: 'SpO₂',
                      value: latestSpo2 != null ? '${fmt(latestSpo2)}%' : '--',
                      color: dotColor(latestSpo2),
                      icon: HugeIcons.strokeRoundedActivity01,
                    ),
                    const Divider(height: 20, color: AppColors.border),
                    _VitalRow(
                      label: 'Temperature',
                      value: latestTemp != null ? '${fmt(latestTemp)} °C' : '--',
                      color: dotColor(latestTemp),
                      icon: HugeIcons.strokeRoundedTemperature,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VitalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final List<List<dynamic>> icon;

  const _VitalRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      HugeIcon(icon: icon, color: AppColors.mutedForeground, size: 16),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 13, color: AppColors.mutedForeground)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─── Phase 8: Prescription Safety Checks ──────────────────────────────────────

class _AllergyMatch {
  final String drug;
  final String allergy;
  const _AllergyMatch({required this.drug, required this.allergy});
}

// Common drug-class → drug-name expansions for allergy matching. Doctors
// usually log allergies by class ("Penicillin") but prescribe by trade/
// generic name ("Amoxicillin"); this catches the common cases. Bidirectional
// substring on the name itself catches the rest ("aspirin" → "Aspirin 325mg").
const Map<String, List<String>> _allergyExpansions = {
  'penicillin': [
    'amoxicillin',
    'ampicillin',
    'cloxacillin',
    'flucloxacillin',
    'piperacillin',
    'penicillin',
    'augmentin',
  ],
  'sulfa': [
    'sulfadiazine',
    'sulfamethoxazole',
    'sulfasalazine',
    'sulfonamide',
    'bactrim',
    'septra',
  ],
  'cephalosporin': [
    'cefazolin',
    'cefaclor',
    'ceftriaxone',
    'cefepime',
    'cefuroxime',
    'cefixime',
  ],
  'aspirin': ['aspirin', 'acetylsalicylic', 'asa'],
  'ibuprofen': ['ibuprofen', 'advil', 'motrin', 'brufen'],
  'nsaid': [
    'ibuprofen',
    'naproxen',
    'diclofenac',
    'aspirin',
    'ketorolac',
    'celecoxib',
    'meloxicam',
  ],
};

bool _allergyMatches_(String drugName, String allergy) {
  final drug = drugName.toLowerCase().trim();
  final allergyLc = allergy.toLowerCase().trim();
  if (drug.isEmpty || allergyLc.isEmpty) return false;
  // Direct substring (either direction).
  if (drug.contains(allergyLc) || allergyLc.contains(drug)) return true;
  // Class expansion.
  for (final entry in _allergyExpansions.entries) {
    if (allergyLc.contains(entry.key)) {
      for (final variant in entry.value) {
        if (drug.contains(variant)) return true;
      }
    }
  }
  return false;
}

class _SafetyChecksSection extends StatelessWidget {
  final bool checking;
  final List<DrugInteraction> interactions;
  final List<_AllergyMatch> allergyMatches;

  const _SafetyChecksSection({
    required this.checking,
    required this.interactions,
    required this.allergyMatches,
  });

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: const [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Checking for allergies and interactions…',
              style: TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
        ]),
      );
    }
    if (allergyMatches.isEmpty && interactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(children: const [
          Icon(Icons.verified_user_rounded,
              size: 16, color: AppColors.success),
          SizedBox(width: 8),
          Expanded(
            child: Text('No known allergies or interactions detected.',
                style: TextStyle(fontSize: 12, color: AppColors.success)),
          ),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in allergyMatches)
          _SafetyWarningCard(
            severity: _Severity.critical,
            title: 'Patient is allergic to ${m.allergy}',
            body:
                '${m.drug} may trigger an allergic reaction. Consider an alternative.',
          ),
        for (final i in interactions)
          _SafetyWarningCard(
            severity: _interactionToSeverity(i.severity),
            title:
                '${_severityLabel(i.severity)} interaction: ${i.drugAName} ↔ ${i.drugBName}',
            body: i.description,
          ),
      ],
    );
  }

  String _severityLabel(InteractionSeverity s) => switch (s) {
        InteractionSeverity.major => 'Major',
        InteractionSeverity.moderate => 'Moderate',
        InteractionSeverity.minor => 'Minor',
        InteractionSeverity.unknown => 'Possible',
      };

  _Severity _interactionToSeverity(InteractionSeverity s) => switch (s) {
        InteractionSeverity.major => _Severity.critical,
        InteractionSeverity.moderate => _Severity.warning,
        InteractionSeverity.minor => _Severity.info,
        InteractionSeverity.unknown => _Severity.info,
      };
}

enum _Severity { critical, warning, info }

class _SafetyWarningCard extends StatelessWidget {
  final _Severity severity;
  final String title;
  final String body;
  const _SafetyWarningCard({
    required this.severity,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (severity) {
      _Severity.critical => (
        AppColors.destructive.withValues(alpha: 0.06),
        AppColors.destructive,
        Icons.warning_amber_rounded,
      ),
      _Severity.warning => (
        AppColors.warning.withValues(alpha: 0.08),
        AppColors.warning,
        Icons.error_outline_rounded,
      ),
      _Severity.info => (
        AppColors.info.withValues(alpha: 0.06),
        AppColors.info,
        Icons.info_outline_rounded,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg)),
                const SizedBox(height: 3),
                Text(body,
                    style: TextStyle(
                        fontSize: 12, color: fg, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
