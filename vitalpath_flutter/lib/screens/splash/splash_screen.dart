import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

const _kOnboardingShownKey = 'onboarding_shown_v2';

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

    // Resolve auth state — wait for the stream's first emission, with a 3 s
    // timeout so we never block the splash indefinitely.
    String? uid = ref.read(firebaseAuthStateProvider).asData?.value?.uid;
    if (uid == null) {
      final streamFuture = ref
          .read(firebaseAuthStateProvider.future)
          .then((u) => u?.uid);
      final timeoutFuture =
          Future<String?>.delayed(const Duration(seconds: 3), () => null);
      uid = await Future.any([streamFuture, timeoutFuture]);
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
            context.go('/caregiver/home');
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

    final splashData = [
      _SplashData(
        color: AppColors.primary,
        title: 'Take Care of Your Health Every Day',
        subtitle: 'Track medicines, meals, and appointments easily in one simple place.',
      ),
      _SplashData(
        color: AppColors.success,
        title: 'Stay Close to Your Patients',
        subtitle: 'Manage appointments and patient updates with ease.',
      ),
      _SplashData(
        color: AppColors.primary,
        title: 'Care for Loved Ones Anytime',
        subtitle: 'Stay updated on your family\'s health and daily care routines.',
      ),
    ];

    final data = splashData[_step];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _nextStep,
        child: SafeArea(
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
                      SvgPicture.asset(
                          _step == 0
                              ? 'assets/icons/Take Care of Your Health Every Day.svg'
                              : _step == 1
                                  ? 'assets/icons/Stay Close to Your Patients.svg'
                                  : 'assets/icons/Care for Loved Ones Anytime.svg',
                          width: 280,
                          height: 220,
                        ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          data.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.mutedForeground,
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
                                borderRadius: BorderRadius.circular(100)),
                          ),
                          child: Text(
                            _step < 2 ? 'Next' : 'Get Started',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _SplashData {
  final Color color;
  final String title;
  final String subtitle;

  const _SplashData({
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
