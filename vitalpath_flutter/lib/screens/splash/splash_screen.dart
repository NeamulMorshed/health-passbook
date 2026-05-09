import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

const _kOnboardingShownKey = 'onboarding_shown';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  int _step = 0;
  bool _navigated = false;
  bool _advancedManually = false;
  bool _onboardingShown = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
    _start();
  }

  Future<void> _start() async {
    // Load the flag and give Firebase Auth time to resolve its persisted session.
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kOnboardingShownKey) ?? false;
    if (seen && mounted) {
      setState(() => _onboardingShown = true);
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (_onboardingShown) {
      // Not first launch — skip carousel, just navigate after auth resolves.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) _navigate();
    } else {
      // First install — run the 3-step onboarding carousel.
      _runOnboardingAnimation();
    }
  }

  void _runOnboardingAnimation() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    // User manually advanced — this scheduled call is stale, bail out.
    if (_advancedManually) {
      _advancedManually = false;
      return;
    }

    if (_step < 2) {
      setState(() => _step++);
      _ctrl
        ..reset()
        ..forward();
      _runOnboardingAnimation();
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) _navigate();
    }
  }

  void _nextStep() {
    _advancedManually = true;
    if (_step < 2) {
      setState(() => _step++);
      _ctrl
        ..reset()
        ..forward();
      _runOnboardingAnimation();
    } else {
      _navigate();
    }
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // Mark onboarding as seen so the carousel never appears again.
    if (!_onboardingShown) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingShownKey, true);
      _onboardingShown = true;
    }

    // Resolve auth state — poll briefly if still loading (max 2 s).
    String? uid = ref.read(firebaseAuthStateProvider).asData?.value?.uid;
    if (uid == null) {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        uid = ref.read(firebaseAuthStateProvider).asData?.value?.uid;
        if (uid != null) break;
      }
    }

    if (!mounted) return;

    if (uid == null) {
      // No signed-in user — go to the role-selection / sign-in entry point.
      context.go('/user-select');
      return;
    }

    final result = await ref.read(authRepositoryProvider).getUserState(uid);
    if (!mounted) return;

    switch (result) {
      case AuthSuccess(:final user):
        if (user.userType == UserType.doctor) {
          if (!user.onboardingComplete) {
            context.go('/doc/onboarding/profile');
          } else {
            context.go('/doc/dashboard');
          }
        } else if (user.userType == UserType.caregiver) {
          if (!user.onboardingComplete) {
            context.go('/onboarding/caregiver-setup');
          } else {
            context.go('/home');
          }
        } else if (!user.onboardingComplete) {
          context.go('/onboarding/permissions');
        } else {
          context.go('/home');
        }

      case AuthNewUser():
        // Signed in via Google but profile not created yet.
        context.go('/user-select');

      case AuthFailure():
      case AuthCancelled():
        context.go('/user-select');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // After first install, show a simple centred logo while auth resolves.
    if (_onboardingShown) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SvgPicture.asset(
              'assets/icons/Starting logo.svg',
              width: 184,
              height: 36,
            ),
          ),
        ),
      );
    }

    const splashData = [
      _SplashData(
        icon: Icons.favorite_rounded,
        color: AppColors.primary,
        title: 'Omra',
        subtitle: 'Your health, in harmony',
      ),
      _SplashData(
        icon: Icons.medical_services_rounded,
        color: AppColors.success,
        title: 'Smart Health Tracking',
        subtitle: 'Medicines, meals, and activity\nall in one place',
      ),
      _SplashData(
        icon: Icons.people_rounded,
        color: AppColors.doctorPrimary,
        title: 'Doctor Connect',
        subtitle: 'Book appointments and receive\nprescriptions instantly',
      ),
    ];

    final data = splashData[_step];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              children: [
                // ── Centre content ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _step == 0
                          ? SvgPicture.asset(
                              'assets/icons/Starting logo.svg',
                              width: 184,
                              height: 36,
                            )
                          : Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: data.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(data.icon, size: 56, color: data.color),
                            ),
                      const SizedBox(height: 32),
                      if (_step > 0)
                        Text(
                          data.title,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: AppColors.foreground,
                          ),
                        ),
                      if (_step > 0) const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          data.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.mutedForeground,
                            fontFamily: 'Inter',
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom section: dots + buttons ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page indicator dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _step ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _step
                                  ? data.color
                                  : data.color.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Next / Get Started button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            _step < 2 ? 'Next' : 'Get Started',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                                color: Colors.white),
                          ),
                        ),
                      ),

                      // Skip link — slides 0 and 1 only
                      if (_step < 2) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _navigate,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                color: AppColors.mutedForeground),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SplashData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
