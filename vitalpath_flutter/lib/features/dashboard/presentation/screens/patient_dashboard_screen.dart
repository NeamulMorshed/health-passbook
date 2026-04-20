import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../medication/presentation/widgets/timeline_widget.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(authStateProvider).valueOrNull;
    final steps     = ref.watch(stepCounterProvider);
    final adherence = ref.watch(todayAdherenceProvider);
    final firstName = user?.name?.split(' ').first ?? 'there';
    final now       = DateTime.now();
    final hour      = now.hour;
    final greeting  = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Sticky header ────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: AppColors.background,
            leading: null,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: AppColors.background),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(greeting, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 0.5)),
                      Text(firstName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text1)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => HapticFeedback.lightImpact(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                    ),
                    child: Center(child: Text(
                      (user?.name?.isNotEmpty == true ? user\!.name\![0] : 'U').toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                    )),
                  ),
                ),
              ],
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Hero card ──────────────────────────────────
              _HeroAdherenceCard(adherence: adherence)
                  .animate().fadeIn(duration: 600.ms).slideY(begin: 0.04),
              const SizedBox(height: 12),

              // ── Step counter ───────────────────────────────
              _StepCard(steps: steps)
                  .animate().fadeIn(duration: 600.ms, delay: 80.ms).slideY(begin: 0.04),
              const SizedBox(height: 16),

              // ── Timeline header ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Today's Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                  Text('${now.day}/${now.month}/${now.year}',
                    style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                ],
              ),
              const SizedBox(height: 12),

              // ── Vertical timeline ──────────────────────────
              const TimelineWidget()
                  .animate().fadeIn(duration: 600.ms, delay: 160.ms),
            ])),
          ),
        ],
      ),
    );
  }
}

// ── Hero Adherence Card ───────────────────────────────────────────────────────

class _HeroAdherenceCard extends StatelessWidget {
  final AsyncValue<({int total, int completed, double pct})> adherence;
  const _HeroAdherenceCard({required this.adherence});

  @override
  Widget build(BuildContext context) {
    return adherence.when(
      loading: () => const _HeroCardSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (d) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.elevatedShadows,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Today\'s Adherence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('${d.completed}/${d.total} doses',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: d.pct,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${(d.pct * 100).round()}% complete',
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _AdherenceRing(pct: d.pct),
          ],
        ),
      ),
    );
  }
}

class _AdherenceRing extends StatefulWidget {
  final double pct;
  const _AdherenceRing({required this.pct});
  @override
  State<_AdherenceRing> createState() => _AdherenceRingState();
}

class _AdherenceRingState extends State<_AdherenceRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = Tween<double>(begin: 0, end: widget.pct)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => CustomPaint(
      size: const Size(72, 72),
      painter: _RingPainter(progress: _anim.value),
      child: Center(child: Text(
        '${(_anim.value * 100).round()}%',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
      )),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width - 8) / 2;
    final bg = Paint()..color = Colors.white.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 6;
    final fg = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, bg);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress \!= progress;
}

class _HeroCardSkeleton extends StatelessWidget {
  const _HeroCardSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 130,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(24),
    ),
  );
}

// ── Step Card ─────────────────────────────────────────────────────────────────

class _StepCard extends ConsumerWidget {
  final int steps;
  const _StepCard({required this.steps});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const goal = AppConstants.defaultDailyStepGoal;
    final pct  = (steps / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.directions_walk_rounded, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Steps Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text3)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 12, color: AppColors.secondary),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.secondary, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(steps.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?\!\d))'), (m) => '${m[1]},'),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.text1)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ ${(goal / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text3)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(stepCounterProvider.notifier).add(100);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('+100', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v, minHeight: 7,
                backgroundColor: AppColors.background,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(pct * 100).round()}% of daily goal',
            style: const TextStyle(fontSize: 11, color: AppColors.text3)),
        ],
      ),
    );
  }
}
