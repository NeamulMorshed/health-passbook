import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

const _kBiometricPref = 'biometric_enabled';

// Fix H4a — isSetupMode distinguishes first-setup from unlock mode.
class FaceIdScreen extends ConsumerStatefulWidget {
  /// When [isSetupMode] is true the user is setting up biometrics for the
  /// first time — skipping writes [biometric_enabled = false].
  /// When false the screen is acting as an unlock gate — skipping just
  /// navigates away without changing the stored preference.
  final bool isSetupMode;

  const FaceIdScreen({super.key, this.isSetupMode = true});

  @override
  ConsumerState<FaceIdScreen> createState() => _FaceIdScreenState();
}

class _FaceIdScreenState extends ConsumerState<FaceIdScreen> {
  final _localAuth = LocalAuthentication();
  bool _checking = false;
  BiometricType? _biometricType;

  // Fix H4b — surface failure feedback to the user.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _detectBiometricType();
  }

  Future<void> _detectBiometricType() async {
    try {
      final types = await _localAuth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          if (types.contains(BiometricType.face)) {
            _biometricType = BiometricType.face;
          } else if (types.contains(BiometricType.fingerprint) ||
              types.contains(BiometricType.strong) ||
              types.contains(BiometricType.weak)) {
            _biometricType = BiometricType.fingerprint;
          }
        });
      }
    } catch (_) {}
  }

  String get _biometricLabel => switch (_biometricType) {
    BiometricType.face => 'Enable Face ID',
    BiometricType.fingerprint => 'Enable Fingerprint',
    _ => 'Enable Biometrics',
  };

  IconData get _biometricIcon => switch (_biometricType) {
    BiometricType.face => Icons.face_retouching_natural_rounded,
    BiometricType.fingerprint => Icons.fingerprint_rounded,
    _ => Icons.lock_open_rounded,
  };

  Future<void> _authenticate() async {
    setState(() {
      _checking = true;
      _errorMessage = null;
    });
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        await _skipWithoutSaving();
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Use biometrics to log into Omra',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (authenticated && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kBiometricPref, true);
        if (mounted) _navigateNext();
      } else if (!authenticated && mounted) {
        // Fix H4b — show feedback when biometric auth returns false.
        setState(() => _errorMessage = 'Authentication failed. Try again.');
      }
    } catch (_) {
      if (mounted) await _skipWithoutSaving();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _navigateNext() async {
    final user = await ref.read(currentUserProvider.future);
    if (!mounted) return;
    if (user?.userType == UserType.doctor) {
      context.go('/doc/dashboard');
    } else if (user?.onboardingComplete == false) {
      context.go('/onboarding/permissions');
    } else {
      context.go('/home');
    }
  }

  Future<void> _skipWithoutSaving() async {
    if (!mounted) return;
    _navigateNext();
  }

  void _skip() async {
    if (widget.isSetupMode) {
      // First-time setup: write false to indicate user declined biometrics.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBiometricPref, false);
      // Fix — mounted check after async pref write.
      if (!mounted) return;
    }
    // In unlock mode (isSetupMode == false): just navigate, don't change pref.
    _navigateNext();
  }

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
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Icon(_biometricIcon, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                _biometricLabel,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    color: AppColors.foreground),
              ),
              const SizedBox(height: 12),
              const Text(
                'Use biometric authentication\nfor faster, more secure login.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter',
                    height: 1.5),
              ),
              // Fix H4b — display auth failure message.
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.red,
                      fontFamily: 'Inter'),
                ),
              ],
              const Spacer(),
              GradientButton(
                  label: _biometricLabel,
                  onPressed: _authenticate,
                  isLoading: _checking),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _checking ? null : _skip,
                child: const Text('Skip for now',
                    style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter')),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
