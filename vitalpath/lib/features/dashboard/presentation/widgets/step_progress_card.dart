import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:intl/intl.dart';

/// Step progress card — real-time step counter with animated progress arc.
/// "Antigravity responsiveness" — the progress bar fills in real-time (SRS §3.1).
class StepProgressCard extends StatelessWidget {
  final int stepCount;
  final int stepGoal;
  final double distanceKm;

  const StepProgressCard({
    super.key,
    required this.stepCount,
    required this.stepGoal,
    required this.distanceKm,
  });

  double get _progress => stepGoal > 0
      ? (stepCount / stepGoal).clamp(0.0, 1.0)
      : 0.0;

  bool get _goalReached => stepCount >= stepGoal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppConstants.routeActivity),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.stepGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular progress indicator
            CircularPercentIndicator(
              radius: 56.0,
              lineWidth: 8.0,
              percent: _progress,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (_goalReached)
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 14),
                ],
              ),
              progressColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.2),
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 800,
            ),

            const SizedBox(width: 20),

            // Stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_walk_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Daily Steps',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat('#,###').format(stepCount),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -1,
                    ),
                  ).animate(key: ValueKey(stepCount)).fadeIn(duration: 200.ms),
                  Text(
                    'of ${NumberFormat('#,###').format(stepGoal)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Distance
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.straighten_rounded,
                        value:
                            '${distanceKm.toStringAsFixed(2)} km',
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.local_fire_department_rounded,
                        value: '${(stepCount * 0.04).toInt()} cal',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
