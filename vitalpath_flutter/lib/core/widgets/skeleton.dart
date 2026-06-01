import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../anim/reduced_motion.dart';

/// A single shimmering placeholder block. Static under reduced motion.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const SkeletonBox(
      {super.key, required this.width, required this.height, this.radius = 8});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion(context)) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else if (!_started) {
      _started = true;
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double opacity) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.surfaceSubtle, AppColors.border, opacity),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) return _box(0.5);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => _box(_ctrl.value),
    );
  }
}

/// Full-screen first-load placeholder shaped like a dashboard.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
      children: const [
        SkeletonBox(width: 120, height: 12),
        SizedBox(height: 8),
        SkeletonBox(width: 180, height: 18),
        SizedBox(height: 20),
        SkeletonBox(width: double.infinity, height: 96, radius: 16), // hero
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 120, radius: 16),
      ],
    );
  }
}
