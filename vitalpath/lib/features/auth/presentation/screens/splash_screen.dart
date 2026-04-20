import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

/// High-performance splash screen with animated VitalPath wordmark (SRS §3.1).
/// Routes to Dashboard (if authenticated) or Onboarding (new user).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Minimum splash display time for brand impression
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final user = ref.read(currentUserProvider);
    if (user != null) {
      context.go(AppConstants.routeDashboard);
    } else {
      context.go(AppConstants.routeOnboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo mark — pulse animation
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 52,
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  duration: 1200.ms,
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.05, 1.05),
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 28),

            // Wordmark
            const Text(
              'VitalPath',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1.0,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0),

            const SizedBox(height: 8),

            const Text(
              'Your Health, Passbooked.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 500.ms),

            const SizedBox(height: 80),

            // Loading indicator
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.6),
                ),
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
