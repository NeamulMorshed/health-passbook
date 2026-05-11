import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/doctor_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../models/activity_log.dart';
import '../../../models/prescription.dart';
import '../../../models/patient.dart';
import '../../../models/consultation_note.dart';
import 'package:intl/intl.dart';

const _uuid = Uuid();

class DocPatientViewScreen extends ConsumerWidget {
  final String patientId;
  const DocPatientViewScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
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
            (_) { if (context.mounted) context.go('/user-select'); },
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
                  subtitle: 'You do not have an active connection with this patient.',
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
    _tabCtrl = TabController(length: 5, vsync: this);
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
    final patientAsync   = ref.watch(patientProfileProvider(widget.patientId));
    final medsAsync      = ref.watch(medicinesProvider(widget.patientId));
    final mealsAsync     = ref.watch(todayMealsProvider(widget.patientId));
    final activityAsync  = ref.watch(activityLogsProvider(widget.patientId));
    final rxAsync        = ref.watch(patientPrescriptionsProvider(widget.patientId));

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
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                tabs: const [
                  Tab(icon: User(width: 18, height: 18), text: 'Overview'),
                  Tab(icon: Icon(Icons.medication_rounded, size: 18), text: 'Medicines'),
                  Tab(icon: Activity(width: 18, height: 18), text: 'Health Log'),
                  Tab(icon: Icon(Icons.description_rounded, size: 18), text: 'Rx History'),
                  Tab(icon: Notes(width: 18, height: 18), text: 'Notes'),
                ],
              ),
            ),
            // ── Tab views ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _OverviewTab(patient: patient, medsAsync: medsAsync),
                  _MedicinesTab(medsAsync: medsAsync),
                  _HealthLogTab(
                    mealsAsync: mealsAsync,
                    activityAsync: activityAsync,
                  ),
                  _PrescriptionsTab(
                    rxAsync: rxAsync,
                    patientId: widget.patientId,
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                  ),
                  _NotesTab(
                    patientId: widget.patientId,
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                  ),
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
  final AsyncValue<List<Medicine>> medsAsync;

  const _OverviewTab({required this.patient, required this.medsAsync});

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

            return Row(children: [
              Expanded(
                child: _InsightChip(
                  icon: Icons.medication_rounded,
                  label: "Today's Meds",
                  value: '$takenToday/$total',
                  subtitle: 'taken today',
                  color: takenToday == total && total > 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightChip(
                  icon: Icons.trending_up_rounded,
                  label: 'Adherence',
                  value: total > 0 ? '$pct%' : '--',
                  subtitle: 'today\'s session',
                  color: total > 0 ? adherenceColor : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightChip(
                  icon: Icons.local_pharmacy_rounded,
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
        if (patient.allergies != null && patient.allergies!.isNotEmpty) ...[
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
                    patient.allergies!,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.destructive),
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
                  const User(width: 16, height: 16, color: AppColors.mutedForeground),
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
                    const Phone(width: 14, height: 14, color: AppColors.mutedForeground),
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
        ],
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: AppColors.border);
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
        AppConstants.freqOnce   => 7,
        AppConstants.freqTwice  => 14,
        AppConstants.freqThrice => 21,
        AppConstants.freqWeekly => 1,
        _                       => 0,
      };

  int get _takenThisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return med.loggedDoses.where((d) => d.isAfter(cutoff)).length;
  }

  @override
  Widget build(BuildContext context) {
    final expected = _expectedPerWeek;
    final taken = _takenThisWeek;
    final adherence =
        expected > 0 ? (taken / expected).clamp(0.0, 1.0) : -1.0;
    final adherencePct =
        adherence >= 0 ? (adherence * 100).round() : null;

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
              child: const Icon(Icons.medication_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text('${med.dosage} · ${med.frequency}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground)),
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
                      fontSize: 11,
                      color: AppColors.mutedForeground)),
              const Spacer(),
              Text('$taken / $expected doses',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: adherenceColor)),
              const SizedBox(width: 6),
              Text('($adherencePct%)',
                  style: TextStyle(
                      fontSize: 11,
                      color: adherenceColor)),
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
                      fontSize: 11,
                      color: AppColors.mutedForeground)),
            ),
          ],

          // Meta row
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (med.prescribedBy != null)
              _MetaChip(
                icon: const User(width: 12, height: 12, color: AppColors.mutedForeground),
                label: 'Dr. ${med.prescribedBy}',
              ),
            _MetaChip(
              icon: const Calendar(width: 12, height: 12, color: AppColors.mutedForeground),
              label: 'Since ${med.startDate.day}/${med.startDate.month}/${med.startDate.year}',
            ),
            _MetaChip(
              icon: const Icon(Icons.history_rounded, size: 11, color: AppColors.mutedForeground),
              label: '${med.loggedDoses.length} total dose${med.loggedDoses.length == 1 ? '' : 's'}',
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
  const _HealthLogTab(
      {required this.mealsAsync, required this.activityAsync});

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
            final totalCal =
                meals.fold(0, (s, m) => s + (m.calories ?? 0));
            final totalProtein =
                meals.fold(0.0, (s, m) => s + (m.protein ?? 0));
            final totalCarbs =
                meals.fold(0.0, (s, m) => s + (m.carbs ?? 0));
            final totalFat =
                meals.fold(0.0, (s, m) => s + (m.fat ?? 0));

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
                      _MacroStat('$totalCal', 'kcal', 'Calories',
                          AppColors.warning),
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
                fontSize: 13,
                color: AppColors.mutedForeground)),
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.description,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(meal.mealType,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground)),
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
    final typeName =
        log.type[0].toUpperCase() + log.type.substring(1);

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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(
                      '${log.loggedAt.day}/${log.loggedAt.month}/${log.loggedAt.year}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground)),
                ]),
          ),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _MetaChip(
              icon: const Icon(Icons.timer_rounded, size: 11, color: AppColors.mutedForeground),
              label: '${mins}m',
            ),
            if (log.distanceKm != null)
              _MetaChip(
                icon: const MapPin(width: 11, height: 11, color: AppColors.mutedForeground),
                label: '${log.distanceKm!.toStringAsFixed(1)} km',
              ),
            if (log.steps != null)
              _MetaChip(
                icon: const Walking(width: 11, height: 11, color: AppColors.mutedForeground),
                label: '${log.steps} steps',
              ),
            if (log.caloriesBurned != null)
              _MetaChip(
                icon: const Icon(Icons.local_fire_department_rounded, size: 11, color: AppColors.mutedForeground),
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
  final String patientId, doctorId, doctorName;

  const _PrescriptionsTab({
    required this.rxAsync,
    required this.patientId,
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
          error: (e, _) =>
              EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
          data: (rxList) {
            if (rxList.isEmpty) {
              return BentoCard(
                child: const Text('No prescriptions on record.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground)),
              );
            }
            const pageSize = 5;
            final visible =
                _showAll ? rxList : rxList.take(pageSize).toList();
            return Column(children: [
              ...visible.map((rx) => _RxCard(rx: rx)),
              if (rxList.length > pageSize)
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  icon: _showAll
                      ? const NavArrowUp(width: 18, height: 18)
                      : const NavArrowDown(width: 18, height: 18),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            Text(
                '${rx.issuedAt.day}/${rx.issuedAt.month}/${rx.issuedAt.year}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground)),
          ]),
          if (rx.diagnosis != null && rx.diagnosis!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(rx.diagnosis!,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground)),
          ],
          const SizedBox(height: 8),
          ...rx.medicines.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.circle,
                      size: 5, color: AppColors.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${m.name} ${m.dosage} (${m.frequency})',
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
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        if (unit.isNotEmpty)
          Text(unit,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground)),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground)),
      ]);
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
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
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground)),
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
            Icon(icon,
                size: 16, color: iconColor ?? AppColors.mutedForeground),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color)),
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
                fontSize: 11,
                color: AppColors.mutedForeground)),
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(unit,
            style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.7))),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.mutedForeground)),
      ]);
}

// ─── Tab 5: Consultation Notes ────────────────────────────────────────────────
class _NotesTab extends ConsumerStatefulWidget {
  final String patientId, doctorId, doctorName;
  const _NotesTab({required this.patientId, required this.doctorId, required this.doctorName});
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save note')));
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
              ? const SizedBox(width: 42, height: 42,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
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
              itemBuilder: (_, i) => _NoteCard(note: notes[i], onDelete: () async {
                await ref.read(consultationNoteNotifierProvider.notifier)
                    .delete(widget.patientId, notes[i].id);
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
  final VoidCallback onDelete;
  const _NoteCard({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.note_alt_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(DateFormat('MMM d, y · h:mm a').format(note.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
          const Spacer(),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Note'),
                content: const Text('Delete this consultation note?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
                    onPressed: () { Navigator.pop(ctx); onDelete(); },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
            child: const Trash(width: 16, height: 16, color: AppColors.destructive),
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
  final String patientId, doctorId, doctorName;
  const _PrescribeSheet(
      {required this.patientId,
      required this.doctorId,
      required this.doctorName});

  @override
  ConsumerState<_PrescribeSheet> createState() => _PrescribeSheetState();
}

class _PrescribeSheetState extends ConsumerState<_PrescribeSheet> {
  final _diagCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_MedEntry> _meds = [_MedEntry()];
  bool _saving = false;

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

  Future<void> _save() async {
    if (_saving) return;

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

    setState(() => _saving = true);
    try {
      await ref.read(prescriptionNotifierProvider.notifier).add(
            patientId: widget.patientId,
            doctorId: widget.doctorId,
            doctorName: widget.doctorName,
            medicines: medicines,
            diagnosis: _diagCtrl.text.trim().isEmpty
                ? null
                : _diagCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
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

      if (mounted) {
        Navigator.pop(context);
        showAppSnack(
          context,
          'Prescription saved · ${medicines.length} medicine${medicines.length == 1 ? '' : 's'} added to patient\'s Care screen',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save prescription. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            TextField(
              controller: _diagCtrl,
              decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  hintText: 'e.g. Type 2 Diabetes'),
            ),
            const SizedBox(height: 16),

            Row(children: [
              const Text('Medicines',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
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
            _saving
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    label: 'Save Prescription',
                    colors: const [AppColors.primary, Color(0xFF5B21B6)],
                    onPressed: _save,
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
