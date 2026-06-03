part of 'caregiver_patient_profile_screen.dart';

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
    _scroll =
        ScrollController(initialScrollOffset: (_todayIndex - 2.5) * _itemW);
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
                              ? AppColors.mutedForeground
                                  .withValues(alpha: 0.35)
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
                              ? AppColors.mutedForeground
                                  .withValues(alpha: 0.35)
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
