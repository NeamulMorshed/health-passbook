import 'package:cloud_firestore/cloud_firestore.dart';

// ── Dose Slot ─────────────────────────────────────────────────────────────────
// Represents one scheduled dose window for a medicine within a single day.
// Windows are derived purely from reminderTimes — no schema change needed.

class DoseSlot {
  final int index;
  final int hour;
  final int minute;
  final DateTime windowStart; // grace period opens 30 min before scheduled time
  final DateTime windowEnd; // closes when the next slot's window starts
  final bool isTaken; // a logged dose falls inside this window
  final bool isDue; // current time >= windowStart
  final bool isMissed; // window has closed and dose was not logged

  const DoseSlot({
    required this.index,
    required this.hour,
    required this.minute,
    required this.windowStart,
    required this.windowEnd,
    required this.isTaken,
    required this.isDue,
    required this.isMissed,
  });

  // "8:00 AM" / "2:00 PM"
  String get displayTime {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return minute == 0 ? '$h $period' : '$h:$m $period';
  }

  // Short label for chips: "8 AM" / "2 PM"
  String get shortTime {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return minute == 0
        ? '$h $period'
        : '$h:${minute.toString().padLeft(2, '0')} $period';
  }
}

// ── Medicine ──────────────────────────────────────────────────────────────────

class Medicine {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String frequency;
  final String? prescribedBy;
  final String? doctorId;
  final String? notes;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final List<DateTime> loggedDoses;
  final List<String> reminderTimes; // "HH:mm" e.g. ["08:00", "20:00"]
  final String
      reminderRepeat; // 'daily' | 'weekly' (legacy, use reminderDays for day selection)
  final List<int>
      reminderDays; // 0=Sun, 1=Mon, …, 6=Sat; empty = use reminderRepeat default
  final String? scannedPhotoUrl; // original prescription photo from OCR scan
  final int? pillsRemaining;

  const Medicine({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.prescribedBy,
    this.doctorId,
    this.notes,
    this.isActive = true,
    required this.startDate,
    this.endDate,
    this.loggedDoses = const [],
    this.reminderTimes = const [],
    this.reminderRepeat = 'daily',
    this.reminderDays = const [0, 1, 2, 3, 4, 5, 6],
    this.scannedPhotoUrl,
    this.pillsRemaining,
  });

  // ── Slot computation ────────────────────────────────────────────────────────

  static const _gracePeriod = Duration(minutes: 30);

  // M3: Use int.tryParse with fallbacks to avoid FormatException on malformed times.
  static (int, int) _parseHM(String t) {
    final p = t.split(':');
    final h = int.tryParse(p.isNotEmpty ? p[0] : '0') ?? 0;
    final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
    return (h, m);
  }

  /// All dose slots for today, sorted by scheduled time.
  List<DoseSlot> get todaySlots {
    if (reminderTimes.isEmpty) return [];

    // Skip days not in the schedule (0=Sun, 1=Mon, …, 6=Sat)
    final todayDow = DateTime.now().weekday %
        7; // Mon=1..Sun=7 → %7 gives Mon=1..Sat=6, Sun=0
    if (reminderDays.isNotEmpty && !reminderDays.contains(todayDow)) return [];

    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);

    // Build sorted scheduled DateTimes for today
    final scheduled = reminderTimes.map((t) {
      final (h, m) = _parseHM(t);
      return DateTime(base.year, base.month, base.day, h, m);
    }).toList()
      ..sort();

    // Today's logged doses only
    final todayDoses = loggedDoses
        .where((d) =>
            d.year == base.year && d.month == base.month && d.day == base.day)
        .toList();

    return List.generate(scheduled.length, (i) {
      final slotTime = scheduled[i];

      // Window opens 30 min early, but never before midnight
      final rawStart = slotTime.subtract(_gracePeriod);
      final windowStart = rawStart.isBefore(base) ? base : rawStart;

      // Window closes when the next slot's window starts, or end of day
      final windowEnd = i + 1 < scheduled.length
          ? scheduled[i + 1].subtract(_gracePeriod)
          : DateTime(base.year, base.month, base.day, 23, 59, 59);

      final isTaken = todayDoses
          .any((d) => !d.isBefore(windowStart) && d.isBefore(windowEnd));
      final isDue = !now.isBefore(windowStart);
      final isMissed = isDue && now.isAfter(windowEnd) && !isTaken;

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

  /// The next slot that is due (window open) but not yet taken.
  /// Returns null when all due slots are taken or no slot has opened yet.
  DoseSlot? get nextPendingSlot =>
      todaySlots.where((s) => s.isDue && !s.isTaken && !s.isMissed).firstOrNull;

  /// The next slot whose window has not opened yet.
  DoseSlot? get nextUpcomingSlot =>
      todaySlots.where((s) => !s.isDue).firstOrNull;

  /// True only when every slot for today has a logged dose.
  bool get fullyTakenToday {
    if (reminderTimes.isEmpty) return _anyDoseToday;
    return todaySlots.every((s) => s.isTaken);
  }

  /// Whether any due slot still needs a dose.
  bool get hasDueSlot {
    if (reminderTimes.isEmpty) return !_anyDoseToday;
    return todaySlots.any((s) => s.isDue && !s.isTaken && !s.isMissed);
  }

  /// Whether any slot's window has closed without a dose.
  bool get hasMissedSlot => todaySlots.any((s) => s.isMissed);

  bool get hasNoScheduledTimes => reminderTimes.isEmpty;

  bool get _anyDoseToday {
    final today = DateTime.now();
    return loggedDoses.any((d) =>
        d.year == today.year && d.month == today.month && d.day == today.day);
  }

  // Kept for backwards compatibility — true when all today's slots are done.
  bool get takenToday => fullyTakenToday;

  // ── Serialisation ───────────────────────────────────────────────────────────

  factory Medicine.fromMap(Map<String, dynamic> map, String id) {
    return Medicine(
      id: id,
      patientId: map['patientId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      prescribedBy: map['prescribedBy'],
      doctorId: map['doctorId'],
      notes: map['notes'],
      isActive: map['isActive'] ?? true,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      loggedDoses: (map['loggedDoses'] as List<dynamic>?)
              ?.map((t) => (t as Timestamp).toDate())
              .toList() ??
          [],
      reminderTimes: (map['reminderTimes'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      reminderRepeat: map['reminderRepeat'] ?? 'daily',
      reminderDays: (() {
        final raw = map['reminderDays'];
        if (raw is List && raw.isNotEmpty) {
          return raw.map((d) => (d as num).toInt()).toList();
        }
        // Backward compat: derive from reminderRepeat
        final repeat = map['reminderRepeat'] ?? 'daily';
        if (repeat == 'weekly') return [1]; // legacy weekly → Monday
        return [0, 1, 2, 3, 4, 5, 6]; // legacy daily → every day
      })(),
      scannedPhotoUrl: map['scannedPhotoUrl'] as String?,
      pillsRemaining: map['pillsRemaining'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'prescribedBy': prescribedBy,
        'doctorId': doctorId,
        'notes': notes,
        'isActive': isActive,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'loggedDoses': loggedDoses.map((d) => Timestamp.fromDate(d)).toList(),
        'reminderTimes': reminderTimes,
        'reminderRepeat': reminderRepeat,
        'reminderDays': reminderDays,
        'scannedPhotoUrl': scannedPhotoUrl,
        'pillsRemaining': pillsRemaining,
      };
}
