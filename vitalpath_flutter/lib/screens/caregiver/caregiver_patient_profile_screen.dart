import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/appointment.dart';
import '../../../models/caregiver_connection.dart';
import '../../../models/meal.dart';
import '../../../models/medicine.dart';
import '../../../models/vital_reading.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/vitals_provider.dart';

// ── Local provider: meals for an arbitrary date (caregiver view only) ─────────

typedef _MealsKey = ({String patientId, DateTime date});

final _cgMealsProvider =
    StreamProvider.family<List<MealLog>, _MealsKey>((ref, key) {
  final start = DateTime(key.date.year, key.date.month, key.date.day);
  final end = start.add(const Duration(days: 1));
  return FirebaseFirestore.instance
      .collection(AppConstants.colPatients)
      .doc(key.patientId)
      .collection(AppConstants.colMeals)
      .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('loggedAt', isLessThan: Timestamp.fromDate(end))
      .orderBy('loggedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => MealLog.fromMap(d.data(), d.id)).toList());
});

// ── Accent colours — warm amber, distinct from doctor (primary blue) ──────────

const _kAmber = Color(0xFFF59E0B);
const _kAmberDark = Color(0xFFD97706);

// ── Screen ────────────────────────────────────────────────────────────────────

class CaregiverPatientProfileScreen extends ConsumerStatefulWidget {
  final CaregiverConnection connection;
  const CaregiverPatientProfileScreen({super.key, required this.connection});

  @override
  ConsumerState<CaregiverPatientProfileScreen> createState() =>
      _CaregiverPatientProfileScreenState();
}

class _CaregiverPatientProfileScreenState
    extends ConsumerState<CaregiverPatientProfileScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isToday {
    final t = _dateOnly(DateTime.now());
    return _selectedDate == t;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final conn = widget.connection;
    final p = conn.permissions;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          // ── Warm amber header — intentionally different from doctor portal ──
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: _kAmber,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(64, 0, 16, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conn.patientName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(conn.relationship.relationshipLabel,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70)),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kAmber, _kAmberDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: const Alignment(-0.82, 0.4),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(conn.patientName),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Date strip ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DateStrip(
              selected: _selectedDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
          ),

          // ── Dashboard ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Date label
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _isToday
                        ? 'Today — ${DateFormat('EEEE, MMMM d').format(_selectedDate)}'
                        : DateFormat('EEEE, MMMM d').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isToday ? _kAmber : AppColors.mutedForeground,
                    ),
                  ),
                ),

                if (p.medicines) ...[
                  _MissedDoseNudge(patientId: conn.patientId),
                  _MedicinesSection(
                      patientId: conn.patientId, selectedDate: _selectedDate),
                  const SizedBox(height: 18),
                ],

                if (p.appointments) ...[
                  _AppointmentSection(patientId: conn.patientId),
                  const SizedBox(height: 18),
                ],

                if (p.mealLogs) ...[
                  _MealsSection(
                      patientId: conn.patientId, selectedDate: _selectedDate),
                  const SizedBox(height: 18),
                ],

                if (p.vitals) ...[
                  _VitalsSection(patientId: conn.patientId),
                  const SizedBox(height: 18),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date strip ────────────────────────────────────────────────────────────────

class _DateStrip extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  const _DateStrip({required this.selected, required this.onSelect});

  @override
  State<_DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<_DateStrip> {
  late final ScrollController _scroll;

  static const _itemW = 56.0;
  static const _totalDays = 14; // 7 past + today + 6 future
  static const _todayIndex = 7;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(
        initialScrollOffset: (_todayIndex - 2.5) * _itemW);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime _dateAt(int i) {
    final base = DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    return today.add(Duration(days: i - _todayIndex));
  }

  bool _isSelected(int i) => _dateAt(i) == widget.selected;

  bool _isToday(int i) {
    final d = _dateAt(i);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isFuture(int i) {
    final now = DateTime.now();
    return _dateAt(i).isAfter(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 72,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _totalDays,
        itemBuilder: (_, i) {
          final d = _dateAt(i);
          final sel = _isSelected(i);
          final today = _isToday(i);
          final future = _isFuture(i);

          return GestureDetector(
            onTap: future ? null : () => widget.onSelect(d),
            child: Container(
              width: _itemW,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: sel
                    ? _kAmber
                    : today
                        ? _kAmber.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(d),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: sel
                          ? Colors.white
                          : future
                              ? AppColors.mutedForeground.withValues(alpha: 0.35)
                              : AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: sel
                          ? Colors.white
                          : future
                              ? AppColors.mutedForeground.withValues(alpha: 0.35)
                              : AppColors.foreground,
                    ),
                  ),
                  if (today && !sel)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _kAmber),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Section shell ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? badge;
  final Color? badgeColor;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    this.badge,
    this.badgeColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          icon,
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppColors.mutedForeground)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(badge!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor ?? AppColors.mutedForeground)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

// ── Medicines section ─────────────────────────────────────────────────────────

class _MedicinesSection extends ConsumerWidget {
  final String patientId;
  final DateTime selectedDate;
  const _MedicinesSection(
      {required this.patientId, required this.selectedDate});

  List<DoseSlot> _slotsForDate(Medicine med, DateTime date) {
    if (med.reminderTimes.isEmpty) return [];
    // Respect day-of-week schedule (e.g. Mon–Fri only medicines)
    final dow = date.weekday % 7; // Mon=1…Sat=6, Sun=0
    if (med.reminderDays.isNotEmpty && !med.reminderDays.contains(dow)) {
      return [];
    }
    final base = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final isSelectedToday = base.year == now.year &&
        base.month == now.month &&
        base.day == now.day;
    final isPast = base.isBefore(DateTime(now.year, now.month, now.day));

    final scheduled = med.reminderTimes.map((t) {
      final parts = t.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateTime(base.year, base.month, base.day, h, m);
    }).toList()
      ..sort();

    final dateDoses = med.loggedDoses
        .where((d) =>
            d.year == base.year &&
            d.month == base.month &&
            d.day == base.day)
        .toList();

    return List.generate(scheduled.length, (i) {
      final slotTime = scheduled[i];
      final rawStart = slotTime.subtract(const Duration(minutes: 30));
      final windowStart = rawStart.isBefore(base) ? base : rawStart;
      final windowEnd = i + 1 < scheduled.length
          ? scheduled[i + 1].subtract(const Duration(minutes: 30))
          : DateTime(base.year, base.month, base.day, 23, 59, 59);
      final isTaken = dateDoses.any(
          (d) => !d.isBefore(windowStart) && d.isBefore(windowEnd));
      final isDue = isSelectedToday ? !now.isBefore(windowStart) : true;
      final isMissed =
          isDue && (isSelectedToday ? now.isAfter(windowEnd) : isPast) && !isTaken;

      return DoseSlot(
        index: i,
        hour: slotTime.hour,
        minute: slotTime.minute,
        windowStart: windowStart,
        windowEnd: windowEnd,
        isTaken: isTaken,
        isDue: isDue,
        isMissed: isMissed,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(patientId));

    return medsAsync.when(
      loading: () => const _SectionSkeleton(),
      error: (_, __) => const _ErrorTile('Could not load medicines'),
      data: (meds) {
        final active = meds.where((m) => m.isActive).toList();
        if (active.isEmpty) {
          return _Section(
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedMedicine01,
                color: _kAmber,
                size: 18),
            title: 'Medicines',
            children: [const _EmptyTile('No active medicines')],
          );
        }

        int taken = 0, total = 0;
        for (final m in active) {
          final slots = _slotsForDate(m, selectedDate);
          if (slots.isEmpty) {
            total++;
            if (m.loggedDoses.any((d) =>
                d.year == selectedDate.year &&
                d.month == selectedDate.month &&
                d.day == selectedDate.day)) { taken++; }
          } else {
            for (final s in slots) {
              total++;
              if (s.isTaken) taken++;
            }
          }
        }

        final allTaken = total > 0 && taken == total;

        return _Section(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedMedicine01,
              color: _kAmber,
              size: 18),
          title: 'Medicines',
          badge: '$taken/$total',
          badgeColor: allTaken ? AppColors.success : AppColors.warning,
          children: active
              .map((med) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MedRow(
                        medicine: med,
                        slots: _slotsForDate(med, selectedDate),
                        selectedDate: selectedDate),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MedRow extends StatelessWidget {
  final Medicine medicine;
  final List<DoseSlot> slots;
  final DateTime selectedDate;
  const _MedRow(
      {required this.medicine,
      required this.slots,
      required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final hasDoseOnDate = medicine.loggedDoses.any((d) =>
        d.year == selectedDate.year &&
        d.month == selectedDate.month &&
        d.day == selectedDate.day);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFutureDate = selectedDate.isAfter(today);

    final allTaken =
        slots.isNotEmpty ? slots.every((s) => s.isTaken) : hasDoseOnDate;
    final anyMissed =
        slots.isNotEmpty ? slots.any((s) => s.isMissed) : false;

    // Future dates: nothing is due yet — show neutral, not amber warning
    final statusColor = isFutureDate
        ? AppColors.mutedForeground
        : allTaken
            ? AppColors.success
            : anyMissed
                ? AppColors.destructive
                : AppColors.warning;
    final statusIcon = isFutureDate
        ? Icons.radio_button_unchecked_rounded
        : allTaken
            ? Icons.check_circle_rounded
            : anyMissed
                ? Icons.cancel_rounded
                : Icons.radio_button_unchecked_rounded;

    return BentoCard(
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${medicine.dosage}  ·  ${medicine.frequency}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground)),
                if (slots.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children:
                        slots.map((s) => _DoseChip(slot: s)).toList(),
                  ),
                ],
              ]),
        ),
      ]),
    );
  }
}

class _DoseChip extends StatelessWidget {
  final DoseSlot slot;
  const _DoseChip({required this.slot});

  @override
  Widget build(BuildContext context) {
    final color = slot.isTaken
        ? AppColors.success
        : slot.isMissed
            ? AppColors.destructive
            : AppColors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          slot.isTaken
              ? Icons.check_rounded
              : slot.isMissed
                  ? Icons.close_rounded
                  : Icons.access_time_rounded,
          size: 10,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(slot.displayTime,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

// ── Appointment section ───────────────────────────────────────────────────────

class _AppointmentSection extends ConsumerWidget {
  final String patientId;
  const _AppointmentSection({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptAsync = ref.watch(
        patientAppointmentsProvider((patientId: patientId, limit: 20)));

    return apptAsync.when(
      loading: () => const _SectionSkeleton(),
      error: (_, __) => const _ErrorTile('Could not load appointments'),
      data: (list) {
        final now = DateTime.now();
        final upcoming = list
            .where((a) =>
                (a.isConfirmed || a.isPending) &&
                a.scheduledAt != null &&
                a.scheduledAt!.isAfter(now))
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

        return _Section(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              color: _kAmber,
              size: 18),
          title: 'Upcoming Appointments',
          badge: upcoming.isEmpty ? null : '${upcoming.length}',
          badgeColor: _kAmber,
          children: upcoming.isEmpty
              ? [const _EmptyTile('No upcoming appointments')]
              : upcoming.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ApptCard(appt: a))).toList(),
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
    final at = appt.scheduledAt!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final apptDay = DateTime(at.year, at.month, at.day);

    final dayLabel = apptDay == today
        ? 'Today'
        : apptDay == tomorrow
            ? 'Tomorrow'
            : DateFormat('EEE, MMM d').format(at);

    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _kAmber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(
              DateFormat('MMM').format(at).toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kAmber),
            ),
            Text(
              '${at.day}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kAmber),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. ${appt.doctorName}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (appt.doctorSpecialty != null) ...[
                  Text(appt.doctorSpecialty!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground)),
                ],
                Text('$dayLabel · ${DateFormat('h:mm a').format(at)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground)),
              ]),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: appt.isConfirmed
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            appt.isConfirmed ? 'Confirmed' : 'Pending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appt.isConfirmed
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Meals section ─────────────────────────────────────────────────────────────

class _MealsSection extends ConsumerWidget {
  final String patientId;
  final DateTime selectedDate;
  const _MealsSection(
      {required this.patientId, required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(
        _cgMealsProvider((patientId: patientId, date: selectedDate)));

    return mealsAsync.when(
      loading: () => const _SectionSkeleton(),
      error: (_, __) => const _ErrorTile('Could not load meals'),
      data: (meals) {
        const types = [
          AppConstants.mealBreakfast,
          AppConstants.mealLunch,
          AppConstants.mealDinner,
        ];

        return _Section(
          icon:
              const Icon(Icons.restaurant_rounded, color: _kAmber, size: 18),
          title: 'Meals',
          children: [
            BentoCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: types.asMap().entries.map((entry) {
                  final i = entry.key;
                  final type = entry.value;
                  final logged =
                      meals.where((m) => m.mealType == type).toList();
                  final isLogged = logged.isNotEmpty;
                  final calories = logged.fold<int>(
                      0, (acc, m) => acc + (m.calories ?? 0));
                  final desc = logged.isNotEmpty &&
                          logged.first.description.isNotEmpty
                      ? logged.first.description
                      : null;

                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(children: [
                        _mealIcon(type),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(type,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                if (desc != null)
                                  Text(desc,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color:
                                              AppColors.mutedForeground),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                              ]),
                        ),
                        if (isLogged && calories > 0) ...[
                          Text('$calories kcal',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mutedForeground)),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLogged
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.muted,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            isLogged ? 'Logged' : 'Not logged',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isLogged
                                    ? AppColors.success
                                    : AppColors.mutedForeground),
                          ),
                        ),
                      ]),
                    ),
                    if (i < types.length - 1)
                      const Divider(
                          height: 1, indent: 14, endIndent: 14),
                  ]);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mealIcon(String type) {
    if (type == AppConstants.mealBreakfast) {
      return HugeIcon(
          icon: HugeIcons.strokeRoundedSun01, color: _kAmber, size: 18);
    }
    if (type == AppConstants.mealLunch) {
      return HugeIcon(
          icon: HugeIcons.strokeRoundedSun01,
          color: AppColors.primary,
          size: 18);
    }
    return HugeIcon(
        icon: HugeIcons.strokeRoundedMoon,
        color: const Color(0xFF8B5CF6),
        size: 18);
  }
}

// ── Vitals section ────────────────────────────────────────────────────────────

class _VitalsSection extends ConsumerWidget {
  final String patientId;
  const _VitalsSection({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsAsync = ref.watch(vitalsProvider(patientId));

    return vitalsAsync.when(
      loading: () => const _SectionSkeleton(),
      error: (_, __) => const _ErrorTile('Could not load vitals'),
      data: (readings) {
        final Map<String, VitalReading> latest = {};
        for (final r in readings) {
          if (!latest.containsKey(r.type) ||
              r.recordedAt.isAfter(latest[r.type]!.recordedAt)) {
            latest[r.type] = r;
          }
        }

        if (latest.isEmpty) {
          return _Section(
            icon: const Icon(Icons.monitor_heart_rounded,
                color: _kAmber, size: 18),
            title: 'Latest Vitals',
            children: [const _EmptyTile('No vitals recorded yet')],
          );
        }

        final screenW = MediaQuery.of(context).size.width;
        final tileW = (screenW - 52) / 2;

        return _Section(
          icon: const Icon(Icons.monitor_heart_rounded,
              color: _kAmber, size: 18),
          title: 'Latest Vitals',
          children: [
            BentoCard(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: latest.values.map((r) {
                  final label = VitalType.labelFor(r.type);
                  final unit = VitalType.unitFor(r.type);
                  final normal = VitalType.isNormal(r.type, r.value);
                  return SizedBox(
                    width: tileW,
                    child: Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: normal
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mutedForeground)),
                              Text('${r.value} $unit',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Missed dose nudge ─────────────────────────────────────────────────────────

class _MissedDoseNudge extends ConsumerWidget {
  final String patientId;
  const _MissedDoseNudge({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(patientId));
    return medsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meds) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final missed = meds.where((m) {
          if (!m.isActive) return false;
          if (m.reminderTimes.isEmpty) return false;
          final base = DateTime(today.year, today.month, today.day);
          final scheduled = m.reminderTimes.map((t) {
            final parts = t.split(':');
            final h = int.tryParse(parts[0]) ?? 0;
            final min = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
            return DateTime(base.year, base.month, base.day, h, min);
          }).toList()..sort();
          final dateDoses = m.loggedDoses.where((d) =>
              d.year == today.year && d.month == today.month && d.day == today.day).toList();
          return List.generate(scheduled.length, (i) {
            final slotTime = scheduled[i];
            if (slotTime.isAfter(now)) return false;
            final rawStart = slotTime.subtract(const Duration(minutes: 30));
            final windowStart = rawStart.isBefore(base) ? base : rawStart;
            final windowEnd = i + 1 < scheduled.length
                ? scheduled[i + 1].subtract(const Duration(minutes: 30))
                : DateTime(base.year, base.month, base.day, 23, 59, 59);
            return !dateDoses.any((d) => !d.isBefore(windowStart) && d.isBefore(windowEnd));
          }).any((isMissed) => isMissed);
        }).toList();

        if (missed.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.destructive.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.destructive, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missed.length == 1
                      ? '${missed.first.name} hasn\'t been taken yet today.'
                      : '${missed.length} medicines haven\'t been taken yet today.',
                  style: const TextStyle(fontSize: 13, color: AppColors.destructive, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _kAmber),
        ),
      );
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile(this.message);
  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.destructive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.destructive)),
          ),
        ]),
      );
}

class _EmptyTile extends StatelessWidget {
  final String message;
  const _EmptyTile(this.message);
  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(14),
        child: Text(message,
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
      );
}
