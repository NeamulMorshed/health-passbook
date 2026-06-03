import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../anim/reduced_motion.dart';

enum HeroTone { positive, warning }

/// Value object describing a daily status hero. Screens compute this from their
/// existing providers and pass it in — the widget stays provider-free + testable.
class StatusHeroData {
  final double fraction; // 0.0–1.0 ring fill
  final String ringLabel; // e.g. '2/3' or '✓'
  final String pillLabel; // e.g. 'ON TRACK'
  final HeroTone tone;
  final String title;
  final String subtitle;
  final String? actionLabel; // null → no button
  const StatusHeroData({
    required this.fraction,
    required this.ringLabel,
    required this.pillLabel,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.actionLabel,
  });
}

/// One row in the doctor schedule-variant hero.
class ScheduleRow {
  final String time, name, status;
  final bool confirmed;
  const ScheduleRow({
    required this.time,
    required this.name,
    required this.status,
    required this.confirmed,
  });
}

/// The single elevated+tinted hero card per home screen.
///
/// Two shapes:
///  * default — progress ring + pill + title/subtitle + optional action
///  * [StatusHeroCard.schedule] — doctor's today-appointment list
class StatusHeroCard extends StatelessWidget {
  final StatusHeroData data;
  final VoidCallback? onAction;

  // schedule-variant fields (null for the default variant)
  final List<ScheduleRow>? _rows;
  final String? _dateLabel;
  final VoidCallback? _onOpen;

  const StatusHeroCard({super.key, required this.data, this.onAction})
      : _rows = null,
        _dateLabel = null,
        _onOpen = null;

  const StatusHeroCard.schedule({
    super.key,
    required List<ScheduleRow> rows,
    required String dateLabel,
    required VoidCallback onOpen,
  })  : data = const StatusHeroData(
          fraction: 0,
          ringLabel: '',
          pillLabel: '',
          tone: HeroTone.positive,
          title: '',
          subtitle: '',
        ),
        onAction = null,
        _rows = rows,
        _dateLabel = dateLabel,
        _onOpen = onOpen;

  @override
  Widget build(BuildContext context) {
    if (_rows != null) return _buildSchedule(context);

    final warn = data.tone == HeroTone.warning;
    final accent = warn ? AppColors.warning : AppColors.primary;
    final bg = warn ? AppColors.warningLight : AppColors.primaryXLight;
    final pillBg = warn ? AppColors.warningLight : AppColors.successLight;
    final pillFg = warn ? AppColors.warning : AppColors.success;
    final reduce = prefersReducedMotion(context);
    final allDone = data.fraction >= 1.0 && !warn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: warn ? AppShadows.heroWarning : AppShadows.hero,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (allDone)
            _CelebrateRing(
                fraction: data.fraction,
                label: data.ringLabel,
                accent: accent,
                animate: !reduce)
          else
            _Ring(
                fraction: data.fraction,
                label: data.ringLabel,
                accent: accent,
                animate: !reduce),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: pillBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(data.pillLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: pillFg)),
                ),
                const SizedBox(height: 5),
                Text(data.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: warn
                            ? const Color(0xFF92400E)
                            : AppColors.primaryDark)),
                const SizedBox(height: 2),
                Text(data.subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
        ]),
        if (data.actionLabel != null) ...[
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size(double.infinity, 44)),
                child: Text(data.actionLabel!),
              )),
        ],
      ]),
    );
  }

  Widget _buildSchedule(BuildContext context) {
    final rows = _rows!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.hero,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
              rows.isEmpty
                  ? 'Today'
                  : 'Today · ${rows.length} appointment${rows.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(20)),
            child: Text(_dateLabel!,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info)),
          ),
        ]),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No appointments today',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)))
        else
          ...rows.take(4).map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text('${r.time}   ${r.name}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis)),
                      Text(r.status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: r.confirmed
                                  ? AppColors.success
                                  : AppColors.warning)),
                    ]),
              )),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onOpen,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 44)),
              child: const Text('Open appointments'),
            )),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  final double fraction;
  final String label;
  final Color accent;
  final bool animate;
  const _Ring(
      {required this.fraction,
      required this.label,
      required this.accent,
      required this.animate});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : fraction, end: fraction),
      duration: Duration(milliseconds: animate ? 300 : 0),
      curve: Curves.easeOut,
      builder: (_, value, __) => SizedBox(
        width: 54,
        height: 54,
        child: CustomPaint(
          painter: _RingPainter(value, accent),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent))),
        ),
      ),
    );
  }
}

/// All-done ring that does one gentle scale pulse + medium haptic, once.
class _CelebrateRing extends StatefulWidget {
  final double fraction;
  final String label;
  final Color accent;
  final bool animate;
  const _CelebrateRing(
      {required this.fraction,
      required this.label,
      required this.accent,
      required this.animate});

  @override
  State<_CelebrateRing> createState() => _CelebrateRingState();
}

class _CelebrateRingState extends State<_CelebrateRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        safeHaptic(context, medium: true);
        _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: _Ring(
          fraction: widget.fraction,
          label: widget.label,
          accent: widget.accent,
          animate: false),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color accent;
  _RingPainter(this.fraction, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = accent.withValues(alpha: 0.15);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -1.5708,
        6.2832 * fraction.clamp(0.0, 1.0), false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.accent != accent;
}
