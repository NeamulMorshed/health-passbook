import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../models/appointment.dart';
import '../../../models/caregiver_connection.dart';
import '../../../models/medicine.dart';
import '../../../models/vital_reading.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/vitals_provider.dart';

class CaregiverPatientProfileScreen extends ConsumerWidget {
  final CaregiverConnection connection;
  const CaregiverPatientProfileScreen({super.key, required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabCount(connection.permissions),
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 140,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(60, 0, 16, 56),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(connection.patientName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(
                      connection.relationship.relationshipLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70),
                    ),
                  ],
                ),
                background: Container(color: AppColors.primary),
              ),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                tabs: _tabs(connection.permissions),
              ),
            ),
          ],
          body: TabBarView(
            children: _tabViews(context, ref, connection),
          ),
        ),
      ),
    );
  }

  int _tabCount(CaregiverPermissions p) {
    int count = 1;
    if (p.vitals) count++;
    if (p.medicines) count++;
    if (p.prescriptions) count++;
    if (p.appointments) count++;
    if (p.mealLogs || p.activityLogs) count++;
    return count;
  }

  List<Tab> _tabs(CaregiverPermissions p) {
    return [
      const Tab(text: 'Overview'),
      if (p.vitals) const Tab(text: 'Vitals'),
      if (p.medicines) const Tab(text: 'Medicines'),
      if (p.prescriptions) const Tab(text: 'Prescriptions'),
      if (p.appointments) const Tab(text: 'Appointments'),
      if (p.mealLogs || p.activityLogs) const Tab(text: 'Logs'),
    ];
  }

  List<Widget> _tabViews(
      BuildContext context, WidgetRef ref, CaregiverConnection conn) {
    return [
      _OverviewTab(patientId: conn.patientId),
      if (conn.permissions.vitals) _VitalsTab(patientId: conn.patientId),
      if (conn.permissions.medicines) _MedicinesTab(patientId: conn.patientId),
      if (conn.permissions.prescriptions)
        _PrescriptionsTab(patientId: conn.patientId),
      if (conn.permissions.appointments)
        _AppointmentsTab(patientId: conn.patientId),
      if (conn.permissions.mealLogs || conn.permissions.activityLogs)
        _LogsTab(
          patientId: conn.patientId,
          showMeals: conn.permissions.mealLogs,
          showActivity: conn.permissions.activityLogs,
        ),
    ];
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final String patientId;
  const _OverviewTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileProvider(patientId));

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load profile',
          subtitle: 'Pull to refresh'),
      data: (profile) {
        if (profile == null) {
          return const EmptyState(
              icon: Icons.person_off_rounded,
              title: 'Profile not found',
              subtitle: '');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            _InfoCard(children: [
              _InfoRow('Blood Type', profile.bloodType ?? '—'),
              _InfoRow('Age', profile.age != null ? '${profile.age} years' : '—'),
              _InfoRow(
                  'Height',
                  profile.height != null
                      ? '${profile.height!.toStringAsFixed(0)} cm'
                      : '—'),
              _InfoRow(
                  'Weight',
                  profile.weight != null
                      ? '${profile.weight!.toStringAsFixed(1)} kg'
                      : '—'),
            ]),
            const SizedBox(height: 14),
            if (profile.conditions.isNotEmpty) ...[
              _SubTitle('Conditions'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.conditions
                    .map((c) => Chip(
                          label: Text(c,
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.08),
                          side: BorderSide.none,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (profile.allergies != null &&
                profile.allergies!.isNotEmpty) ...[
              _SubTitle('Allergies'),
              const SizedBox(height: 8),
              _InfoCard(children: [
                Text(profile.allergies!,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.destructive)),
              ]),
            ],
          ],
        );
      },
    );
  }
}

// ── Vitals tab ────────────────────────────────────────────────────────────────

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
          title: 'Could not load vitals',
          subtitle: ''),
      data: (readings) {
        if (readings.isEmpty) {
          return const EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'No vitals recorded yet',
              subtitle: '');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: readings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _VitalCard(reading: readings[i]),
        );
      },
    );
  }
}

class _VitalCard extends StatelessWidget {
  final VitalReading reading;
  const _VitalCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final label = VitalType.labelFor(reading.type);
    final unit = VitalType.unitFor(reading.type);
    final normal = VitalType.isNormal(reading.type, reading.value);
    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (normal ? AppColors.success : AppColors.warning)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.monitor_heart_rounded,
              size: 18,
              color: normal ? AppColors.success : AppColors.warning),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(
                  DateFormat('MMM d, y · h:mm a').format(reading.recordedAt),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground)),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${reading.value} $unit',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          if (!normal)
            const Text('⚠️ Abnormal',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.warning)),
        ]),
      ]),
    );
  }
}

// ── Medicines tab ─────────────────────────────────────────────────────────────

class _MedicinesTab extends ConsumerWidget {
  final String patientId;
  const _MedicinesTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(patientId));

    return medsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load medicines',
          subtitle: ''),
      data: (meds) {
        final active = meds.where((m) => m.isActive).toList();
        if (active.isEmpty) {
          return const EmptyState(
              icon: Icons.medication_outlined,
              title: 'No active medicines',
              subtitle: '');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: active.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _MedCard(medicine: active[i]),
        );
      },
    );
  }
}

class _MedCard extends StatelessWidget {
  final Medicine medicine;
  const _MedCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final takenCount = medicine.loggedDoses
        .where((d) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          return d.isAfter(today);
        })
        .length;
    final totalSlots = medicine.reminderTimes.isEmpty
        ? 1
        : medicine.reminderTimes.length;

    return BentoCard(
      padding: const EdgeInsets.all(14),
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
              child: const Icon(Icons.medication_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medicine.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('${medicine.dosage}  •  ${medicine.frequency}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: takenCount >= totalSlots
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$takenCount/$totalSlots today',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: takenCount >= totalSlots
                        ? AppColors.success
                        : AppColors.warning),
              ),
            ),
          ]),
          if (medicine.notes != null && medicine.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(medicine.notes!,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

// ── Prescriptions tab ─────────────────────────────────────────────────────────

class _PrescriptionsTab extends ConsumerWidget {
  final String patientId;
  const _PrescriptionsTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rxAsync = ref.watch(patientPrescriptionsProvider(patientId));

    return rxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load prescriptions',
          subtitle: ''),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No prescriptions yet',
              subtitle: '');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final rx = list[i];
            return BentoCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 18, color: AppColors.doctorPrimary),
                    const SizedBox(width: 10),
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
                                  color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ]),
                  if (rx.diagnosis != null && rx.diagnosis!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(rx.diagnosis!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.mutedForeground)),
                  ],
                  const SizedBox(height: 10),
                  ...rx.medicines.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          const Icon(Icons.circle,
                              size: 5, color: AppColors.doctorPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${m.name}  ${m.dosage}  •  ${m.frequency}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ]),
                      )),
                  if (rx.documentUrl != null && rx.documentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: rx.documentUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(height: 120, color: AppColors.muted),
                        errorWidget: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Appointments tab ──────────────────────────────────────────────────────────

class _AppointmentsTab extends ConsumerWidget {
  final String patientId;
  const _AppointmentsTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptAsync = ref.watch(
        patientAppointmentsProvider((patientId: patientId, limit: 20)));

    return apptAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load appointments',
          subtitle: ''),
      data: (list) {
        final upcoming =
            list.where((a) => a.isConfirmed || a.isPending).toList();
        final past =
            list.where((a) => a.isCompleted || a.isCancelled).toList();

        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No appointments',
              subtitle: '');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            if (upcoming.isNotEmpty) ...[
              _SubTitle('Upcoming'),
              const SizedBox(height: 8),
              ...upcoming.map((a) => _ApptCard(appt: a)),
              const SizedBox(height: 20),
            ],
            if (past.isNotEmpty) ...[
              _SubTitle('Past'),
              const SizedBox(height: 8),
              ...past.map((a) => _ApptCard(appt: a)),
            ],
          ],
        );
      },
    );
  }
}

class _ApptCard extends StatelessWidget {
  final Appointment appt;
  const _ApptCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final statusColor = appt.isConfirmed
        ? AppColors.success
        : appt.isPending
            ? AppColors.warning
            : appt.isCancelled
                ? AppColors.destructive
                : AppColors.mutedForeground;
    final statusLabel =
        appt.status.value[0].toUpperCase() + appt.status.value.substring(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Calendar(width: 18, height: 18, color: AppColors.doctorPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. ${appt.doctorName}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(
                    appt.scheduledAt != null
                        ? DateFormat('MMM d, y · h:mm a')
                            .format(appt.scheduledAt!)
                        : 'Date TBD',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Logs tab ──────────────────────────────────────────────────────────────────

class _LogsTab extends ConsumerWidget {
  final String patientId;
  final bool showMeals;
  final bool showActivity;

  const _LogsTab({
    required this.patientId,
    required this.showMeals,
    required this.showActivity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync =
        showMeals ? ref.watch(todayMealsProvider(patientId)) : null;
    final activityAsync =
        showActivity ? ref.watch(activityLogsProvider(patientId)) : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        if (showMeals && mealsAsync != null) ...[
          _SubTitle('Today\'s Meals'),
          const SizedBox(height: 8),
          mealsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Could not load meals'),
            data: (meals) {
              if (meals.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('No meals logged today',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedForeground)),
                );
              }
              return Column(
                children: meals
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BentoCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              const Icon(Icons.restaurant_rounded,
                                  size: 16, color: AppColors.warning),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${m.mealType}: ${m.description.isNotEmpty ? m.description : "Logged"}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (m.calories != null)
                                Text('${m.calories} kcal',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedForeground)),
                            ]),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        if (showActivity && activityAsync != null) ...[
          _SubTitle('Recent Activity'),
          const SizedBox(height: 8),
          activityAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Could not load activity'),
            data: (logs) {
              final recent = logs.take(5).toList();
              if (recent.isEmpty) {
                return const Text('No activity logged recently',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.mutedForeground));
              }
              return Column(
                children: recent
                    .map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BentoCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              const Icon(Icons.directions_run_rounded,
                                  size: 16, color: AppColors.success),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l.type,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (l.steps != null)
                                Text('${l.steps} steps',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedForeground)),
                            ]),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700));
  }
}
