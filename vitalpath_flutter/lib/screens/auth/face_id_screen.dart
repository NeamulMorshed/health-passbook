import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

class FaceIdScreen extends ConsumerStatefulWidget {
  const FaceIdScreen({super.key});
  @override
  ConsumerState<FaceIdScreen> createState() => _FaceIdScreenState();
}

class _FaceIdScreenState extends ConsumerState<FaceIdScreen> {
  final _localAuth = LocalAuthentication();
  bool _checking = false;

  Future<void> _authenticate() async {
    setState(() => _checking = true);
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (\!canCheck) {
        _skip();
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Use biometrics to log into VitalPath',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (authenticated && mounted) _navigateNext();
    } catch (_) {
      if (mounted) _skip();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _navigateNext() async {
    final user = await ref.read(currentUserProvider.future);
    if (\!mounted) return;
    if (user?.userType == UserType.doctor) {
      context.go('/doc/dashboard');
    } else if (user?.onboardingComplete == false) {
      context.go('/onboarding/permissions');
    } else {
      context.go('/home');
    }
  }

  void _skip() => _navigateNext();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.face_retouching_natural_rounded, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 32),
              const Text('Enable Face ID', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
              const SizedBox(height: 12),
              const Text('Use biometric authentication\nfor faster, more secure login.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.mutedForeground, fontFamily: 'Inter', height: 1.5)),
              const Spacer(),
              GradientButton(label: 'Enable Biometrics', onPressed: _authenticate, isLoading: _checking),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _skip,
                child: const Text('Skip for now', style: TextStyle(color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
