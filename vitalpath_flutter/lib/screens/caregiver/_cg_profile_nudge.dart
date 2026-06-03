part of 'caregiver_patient_profile_screen.dart';

// ── Nudge follow-up indicator ─────────────────────────────────────────────────
// Shows "Aisha took her medicine N min after your nudge" when a dose was logged
// within 2 hours of the last sent nudge. Positive-only: renders nothing if no
// dose was taken in the window. Auto-expires after 4 hours (nudge is stale).

class _NudgeFollowUp extends ConsumerWidget {
  final String patientId, caregiverUid, patientName;
  const _NudgeFollowUp({
    required this.patientId,
    required this.caregiverUid,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mirror = ref
        .watch(caregiverMirrorProvider(
            (patientId: patientId, caregiverUid: caregiverUid)))
        .asData
        ?.value;
    if (mirror == null) return const SizedBox.shrink();

    final nudgeTs = mirror['lastNudgeSentAt'] as Timestamp?;
    if (nudgeTs == null) return const SizedBox.shrink();

    final nudgeAt = nudgeTs.toDate();
    final now = DateTime.now();
    if (now.difference(nudgeAt).inMinutes > 240) return const SizedBox.shrink();

    final meds = ref.watch(medicinesProvider(patientId)).asData?.value ?? [];
    final windowEnd = nudgeAt.add(const Duration(hours: 2));

    final matches = <(Medicine, DateTime)>[];
    for (final m in meds.where((m) => m.isActive)) {
      for (final d in m.loggedDoses) {
        if (d.isAfter(nudgeAt) && d.isBefore(windowEnd)) {
          matches.add((m, d));
        }
      }
    }
    if (matches.isEmpty) return const SizedBox.shrink();

    final first = matches.first;
    final deltaMin = first.$2.difference(nudgeAt).inMinutes;
    final label = matches.length == 1
        ? '$patientName took ${first.$1.name} ${deltaMin}m after your nudge'
        : '$patientName took ${matches.length} medicines after your nudge';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      ),
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
          }).toList()
            ..sort();
          final dateDoses = m.loggedDoses
              .where((d) =>
                  d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day)
              .toList();
          return List.generate(scheduled.length, (i) {
            final slotTime = scheduled[i];
            if (slotTime.isAfter(now)) return false;
            final rawStart = slotTime.subtract(const Duration(minutes: 30));
            final windowStart = rawStart.isBefore(base) ? base : rawStart;
            final windowEnd = i + 1 < scheduled.length
                ? scheduled[i + 1].subtract(const Duration(minutes: 30))
                : DateTime(base.year, base.month, base.day, 23, 59, 59);
            return !dateDoses
                .any((d) => !d.isBefore(windowStart) && d.isBefore(windowEnd));
          }).any((isMissed) => isMissed);
        }).toList();

        if (missed.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAmber.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert01,
                  color: _kAmberDark,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missed.length == 1
                      ? '${missed.first.name} may not have been taken yet — worth a check-in.'
                      : '${missed.length} medicines may not have been taken yet — consider checking in.',
                  style: TextStyle(
                      fontSize: 13,
                      color: _kAmberDark,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Nudge sheet ───────────────────────────────────────────────────────────────

class _NudgeSheet extends ConsumerStatefulWidget {
  final String patientName;
  final String caregiverUid;
  final Future<void> Function(String) onSend;

  const _NudgeSheet({
    required this.patientName,
    required this.caregiverUid,
    required this.onSend,
  });

  @override
  ConsumerState<_NudgeSheet> createState() => _NudgeSheetState();
}

class _NudgeSheetState extends ConsumerState<_NudgeSheet> {
  static const _kDefaults = [
    'Just checking in 💛',
    "Don't forget your medicine!",
    'Thinking of you today',
    'How are you feeling?',
  ];
  static const _kMaxCustom = 5;

  final _ctrl = TextEditingController();
  bool _saveAsPreset = false;
  bool _sending = false;
  List<String> _custom = [];
  bool _loadingPresets = true;
  int _nudgesToday = 0;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _todayIso {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPresets() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.caregiverUid)
        .get();
    if (!mounted) return;
    final data = doc.data();
    final raw = data?['nudgePresets'];
    final storedDate = data?['nudgesTodayDate'] as String?;
    final storedCount = (data?['nudgesTodayCount'] as num?)?.toInt() ?? 0;
    setState(() {
      _custom = raw is List ? List<String>.from(raw) : [];
      _nudgesToday = storedDate == _todayIso ? storedCount : 0;
      _loadingPresets = false;
    });
  }

  Future<void> _send(String message) async {
    if (_sending) return;
    setState(() => _sending = true);

    final updates = <String, dynamic>{};

    if (_saveAsPreset &&
        message.trim().isNotEmpty &&
        _custom.length < _kMaxCustom &&
        !_custom.contains(message.trim())) {
      updates['nudgePresets'] = FieldValue.arrayUnion([message.trim()]);
    }

    // Increment today's nudge count, resetting if the date changed.
    final today = _todayIso;
    updates['nudgesTodayDate'] = today;
    updates['nudgesTodayCount'] =
        _nudgesToday == 0 ? 1 : FieldValue.increment(1);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.caregiverUid)
        .update(updates);

    await widget.onSend(message);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deletePreset(String preset) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.caregiverUid)
        .update({
      'nudgePresets': FieldValue.arrayRemove([preset])
    });
    if (mounted) setState(() => _custom.remove(preset));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send a nudge to ${widget.patientName}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                _nudgesToday > 0
                    ? "You've sent $_nudgesToday nudge${_nudgesToday == 1 ? '' : 's'} today."
                    : "They'll receive a notification from you.",
                style: const TextStyle(
                    fontSize: 13, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              if (_loadingPresets)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else ...[
                ..._kDefaults.map((msg) => _PresetTile(
                      message: msg,
                      onTap: () => _send(msg),
                      isLoading: _sending,
                    )),
                if (_custom.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 6),
                    child: Text('Your presets',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground)),
                  ),
                  ..._custom.map((msg) => _PresetTile(
                        message: msg,
                        onTap: () => _send(msg),
                        isLoading: _sending,
                        onDelete: () => _deletePreset(msg),
                      )),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Write your own…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _send(v.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder(
                    valueListenable: _ctrl,
                    builder: (_, v, __) => IconButton(
                      onPressed: (_sending || v.text.trim().isEmpty)
                          ? null
                          : () => _send(_ctrl.text.trim()),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : HugeIcon(
                              icon: HugeIcons.strokeRoundedSent,
                              color: _kAmber,
                              size: 20),
                    ),
                  ),
                ]),
                if (_custom.length < _kMaxCustom)
                  ValueListenableBuilder(
                    valueListenable: _ctrl,
                    builder: (_, v, __) {
                      if (v.text.trim().isEmpty) return const SizedBox.shrink();
                      return CheckboxListTile(
                        value: _saveAsPreset,
                        onChanged: (val) =>
                            setState(() => _saveAsPreset = val ?? false),
                        title: const Text('Save as preset',
                            style: TextStyle(fontSize: 13)),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _kAmber,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String message;
  final VoidCallback onTap;
  final bool isLoading;
  final VoidCallback? onDelete;

  const _PresetTile({
    required this.message,
    required this.onTap,
    required this.isLoading,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _kAmber.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAmber.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.mutedForeground),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
