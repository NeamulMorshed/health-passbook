import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/app_user.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _advance();
  }

  void _advance() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (\!mounted) return;
    if (_step < 2) {
      setState(() => _step++);
      _ctrl.reset();
      _ctrl.forward();
      _advance();
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      if (\!mounted) return;
      _checkAuthAndNavigate();
    }
  }

  void _checkAuthAndNavigate() {
    final authState = ref.read(firebaseAuthStateProvider);
    authState.when(
      data: (user) async {
        if (user == null) {
          context.go('/user-select');
          return;
        }
        final appUser = await ref.read(authServiceProvider).getUserProfile(user.uid);
        if (appUser == null) {
          context.go('/user-select');
          return;
        }
        if (\!appUser.onboardingComplete && appUser.userType == UserType.patient) {
          context.go('/onboarding/permissions');
          return;
        }
        if (appUser.userType == UserType.doctor) {
          context.go('/doc/dashboard');
        } else {
          context.go('/home');
        }
      },
      loading: () => context.go('/user-select'),
      error: (_, __) => context.go('/user-select'),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splashData = [
      _SplashData(
        icon: Icons.favorite_rounded,
        color: AppColors.primary,
        title: 'VitalPath',
        subtitle: 'Your complete health companion',
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
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, size: 52, color: data.color),
                ),
                const SizedBox(height: 28),
                Text(data.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
                const SizedBox(height: 10),
                Text(data.subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.mutedForeground, fontFamily: 'Inter', height: 1.5)),
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _step ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _step ? data.color : data.color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
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
  const _SplashData({required this.icon, required this.color, required this.title, required this.subtitle});
}
