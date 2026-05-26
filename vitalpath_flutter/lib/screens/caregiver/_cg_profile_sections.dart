part of 'caregiver_patient_profile_screen.dart';

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    final dow = date.weekday % 7;
    if (med.reminderDays.isNotEmpty && !med.reminderDays.contains(dow)) {
      return [];
    }
    final base = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final isSelectedToday =
        base.year == now.year && base.month == now.month && base.day == now.day;
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
            d.year == base.year && d.month == base.month && d.day == base.day)
        .toList();

    return List.generate(scheduled.length, (i) {
      final slotTime = scheduled[i];
      final rawStart = slotTime.subtract(const Duration(minutes: 30));
      final windowStart = rawStart.isBefore(base) ? base : rawStart;
      final windowEnd = i + 1 < scheduled.length
          ? scheduled[i + 1].subtract(const Duration(minutes: 30))
          : DateTime(base.year, base.month, base.day, 23, 59, 59);
      final isTaken = dateDoses
          .any((d) => !d.isBefore(windowStart) && d.isBefore(windowEnd));
      final isDue = isSelectedToday ? !now.isBefore(windowStart) : true;
      final isMissed = isDue &&
          (isSelectedToday ? now.isAfter(windowEnd) : isPast) &&
          !isTaken;

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
                d.day == selectedDate.day)) {
              taken++;
            }
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
          children: [
            if (allTaken)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'All $total medicine${total == 1 ? '' : 's'} taken today — great job!',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ),
            ...active.map((med) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MedRow(
                      medicine: med,
                      slots: _slotsForDate(med, selectedDate),
                      selectedDate: selectedDate),
                )),
          ],
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
    final anyMissed = slots.isNotEmpty ? slots.any((s) => s.isMissed) : false;

    final statusColor = isFutureDate
        ? AppColors.mutedForeground
        : allTaken
            ? AppColors.success
            : anyMissed
                ? AppColors.destructive
                : AppColors.warning;
    final statusIcon = isFutureDate
        ? HugeIcons.strokeRoundedCircle
        : allTaken
            ? HugeIcons.strokeRoundedCheckmarkCircle01
            : anyMissed
                ? HugeIcons.strokeRoundedCancel01
                : HugeIcons.strokeRoundedCircle;

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
          child: HugeIcon(icon: statusIcon, color: statusColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(medicine.name,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${medicine.dosage}  ·  ${medicine.frequency}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
            if (medicine.prescribedBy != null &&
                medicine.prescribedBy!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Dr. ${medicine.prescribedBy}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
            ],
            if (slots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: slots.map((s) => _DoseChip(slot: s)).toList(),
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

  String _overdueLabel() {
    final now = DateTime.now();
    // Reconstruct the scheduled time on the same calendar day as windowEnd.
    final base = DateTime(
        slot.windowEnd.year, slot.windowEnd.month, slot.windowEnd.day,
        slot.hour, slot.minute);
    final diff = now.difference(base);
    if (diff.inMinutes < 1) return slot.displayTime;
    if (diff.inMinutes < 60) return '${slot.displayTime} (${diff.inMinutes}m ago)';
    return '${slot.displayTime} (${diff.inHours}h ago)';
  }

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
        HugeIcon(
          icon: slot.isTaken
              ? HugeIcons.strokeRoundedTick01
              : slot.isMissed
                  ? HugeIcons.strokeRoundedCancel01
                  : HugeIcons.strokeRoundedClock01,
          size: 10,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          slot.isMissed ? _overdueLabel() : slot.displayTime,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color),
        ),
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
    final apptAsync = ref
        .watch(patientAppointmentsProvider((patientId: patientId, limit: 20)));

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
          title: 'Upcoming Visits',
          badge: upcoming.isEmpty ? null : '${upcoming.length}',
          badgeColor: _kAmber,
          children: upcoming.isEmpty
              ? [const _EmptyTile('No upcoming appointments')]
              : upcoming
                  .map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ApptCard(appt: a)))
                  .toList(),
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
                  fontSize: 10, fontWeight: FontWeight.w700, color: _kAmber),
            ),
            Text(
              '${at.day}',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _kAmber),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$dayLabel · ${DateFormat('h:mm a').format(at)}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('with Dr. ${appt.doctorName}',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.foreground)),
            if (appt.doctorSpecialty != null)
              Text(appt.doctorSpecialty!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.mutedForeground)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              color: appt.isConfirmed ? AppColors.success : AppColors.warning,
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
  const _MealsSection({required this.patientId, required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync =
        ref.watch(_cgMealsProvider((patientId: patientId, date: selectedDate)));

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
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRestaurant01,
              color: _kAmber,
              size: 18),
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
                  final calories =
                      logged.fold<int>(0, (acc, m) => acc + (m.calories ?? 0));
                  final desc =
                      logged.isNotEmpty && logged.first.description.isNotEmpty
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                if (desc != null)
                                  Text(desc,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mutedForeground),
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
                      const Divider(height: 1, indent: 14, endIndent: 14),
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
          color: AppColors.success,
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
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedPulse01, color: _kAmber, size: 18),
            title: 'Recent Readings',
            children: [const _EmptyTile('No vitals recorded yet')],
          );
        }

        final screenW = MediaQuery.of(context).size.width;
        final tileW = (screenW - 52) / 2;

        return _Section(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedPulse01, color: _kAmber, size: 18),
          title: 'Recent Readings',
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
                          color: normal ? AppColors.success : AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mutedForeground)),
                              Text('${r.value} $unit',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(_timeAgo(r.recordedAt),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary)),
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

// ── Prescriptions section (read-only) ────────────────────────────────────────

class _PrescriptionsSection extends ConsumerWidget {
  final String patientId;
  const _PrescriptionsSection({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rxAsync = ref.watch(patientPrescriptionsProvider((patientId: patientId, limit: 3)));
    return rxAsync.when(
      loading: () => const _SectionSkeleton(),
      error: (_, __) => const _ErrorTile('Could not load prescriptions'),
      data: (rxList) {
        final recent = rxList.take(3).toList();
        return _Section(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedMedicalFile,
              color: _kAmber,
              size: 18),
          title: 'Prescriptions',
          children: recent.isEmpty
              ? [const _EmptyTile('No prescriptions on record.')]
              : recent.map((rx) => _RxPreviewCard(rx: rx)).toList(),
        );
      },
    );
  }
}

class _RxPreviewCard extends StatelessWidget {
  final Prescription rx;
  const _RxPreviewCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMedicalFile,
                    color: _kAmber,
                    size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. ${rx.doctorName}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      DateFormat('MMM d, y').format(rx.issuedAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${rx.medicines.length} med${rx.medicines.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kAmber),
                ),
              ),
            ]),
            if (rx.diagnosis != null) ...[
              const SizedBox(height: 8),
              Text(rx.diagnosis!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rx.medicines
                  .map((m) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${m.name} ${m.dosage}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedForeground),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Locked section placeholder ────────────────────────────────────────────────

String _sectionLabel(String section) => switch (section) {
      'medicines' => 'Medicines',
      'appointments' => 'Upcoming Visits',
      'mealLogs' => 'Meals',
      'vitals' => 'Recent Readings',
      'prescriptions' => 'Prescriptions',
      _ => section,
    };

class _LockedSection extends StatefulWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String patientName;
  final String section;
  final String connectionId;
  final String patientUid;
  final String caregiverName;

  const _LockedSection({
    required this.icon,
    required this.title,
    required this.patientName,
    required this.section,
    required this.connectionId,
    required this.patientUid,
    required this.caregiverName,
  });

  @override
  State<_LockedSection> createState() => _LockedSectionState();
}

class _LockedSectionState extends State<_LockedSection> {
  bool _requested = false;
  bool _sending = false;

  Future<void> _requestAccess() async {
    if (_requested || _sending) return;
    setState(() => _sending = true);

    try {
      final notif = AppNotification(
        id: '',
        title:
            '${widget.caregiverName} wants to see your ${_sectionLabel(widget.section)}',
        body: 'Tap to grant access.',
        type: NotificationType.permissionRequest,
        isRead: false,
        createdAt: DateTime.now(),
        data: {
          'connectionId': widget.connectionId,
          'section': widget.section,
        },
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('notifications')
          .add(notif.toMap());

      if (mounted) {
        setState(() {
          _requested = true;
          _sending = false;
        });
        AppSnackBar.success(context, 'Asked ${widget.patientName} to grant access.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        AppSnackBar.error(context, 'Could not send request. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => _Section(
        icon: HugeIcon(
            icon: widget.icon, color: AppColors.textTertiary, size: 18),
        title: widget.title,
        children: [
          BentoCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedLock,
                      color: AppColors.textTertiary,
                      size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.patientName} hasn\'t shared this with you yet.',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.mutedForeground),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        (_requested || _sending) ? null : _requestAccess,
                    icon: _sending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.mutedForeground),
                          )
                        : Icon(
                            _requested
                                ? Icons.check_rounded
                                : Icons.lock_open_rounded,
                            size: 16,
                          ),
                    label: Text(
                      _requested ? 'Requested ✓' : 'Request access',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _requested
                          ? AppColors.mutedForeground
                          : _kAmber,
                      side: BorderSide(
                        color: _requested
                            ? AppColors.border
                            : _kAmber,
                      ),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
