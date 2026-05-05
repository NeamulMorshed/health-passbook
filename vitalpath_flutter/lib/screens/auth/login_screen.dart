import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? userType;
  const LoginScreen({super.key, this.userType});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (!mounted) return;

    switch (result) {
      case AuthSuccess(:final user):
        _navigateForUser(user);

      case AuthNewUser(:final uid, email: _, :final displayName):
        if (widget.userType != null) {
          final newUser = AppUser(
            uid: uid,
            name: displayName ?? 'New User',
            phone: '',
            userType: widget.userType == 'doctor' ? UserType.doctor : UserType.patient,
            createdAt: DateTime.now(),
          );
          try {
            await ref.read(authRepositoryProvider).createProfile(newUser);
          } catch (e) {
            if (mounted) setState(() { _loading = false; _error = 'Failed to create profile. Please try again.'; });
            return;
          }
          if (!mounted) return;
          _navigateForUser(newUser);
        } else {
          // No Firestore profile yet and no explicit type — User must choose role.
          context.go('/user-select');
        }

      case AuthCancelled():
        setState(() => _loading = false);

      case AuthFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
    }
  }

  void _navigateForUser(AppUser user) async {
    if (user.userType == UserType.doctor) {
      if (!user.onboardingComplete) {
        if (mounted) context.go('/doc/onboarding/profile');
      } else {
        if (mounted) context.go('/doc/dashboard');
      }
    } else if (!user.onboardingComplete) {
      if (mounted) context.go('/onboarding/permissions');
    } else {
      // Only route through Face ID if the user has biometrics enabled.
      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      if (!mounted) return;
      context.go(biometricEnabled ? '/auth/faceid' : '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _loading,
          message: 'Signing in…',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // ── Brand icon ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    // withValues(alpha:) replaces deprecated withOpacity()
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Heading ────────────────────────────────────────────────
                const Text(
                  'Welcome to\nOmra',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: AppColors.foreground,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your personal health companion.\nSign in to get started.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter',
                    height: 1.5,
                  ),
                ),

                const Spacer(),

                // ── Error banner ───────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_rounded,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Google Sign-In button ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      backgroundColor: AppColors.muted,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Inline Google 'G' glyph — no network request.
                        _GoogleGlyph(),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground.withValues(alpha: 0.7),
                        fontFamily: 'Inter',
                        height: 1.6,
                      ),
                      children: [
                        const TextSpan(text: 'By continuing you agree to our\n'),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              final uri = Uri.parse('https://vitalpath.health/terms');
                              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                        ),
                        const TextSpan(text: ' & '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              final uri = Uri.parse('https://vitalpath.health/privacy');
                              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the multicolour Google 'G' logo inline using a CustomPainter.
/// No network request, no broken-image fallback.
class _GoogleGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.38;

    // Blue arc (right half)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        -0.45, 2.45, false, paint);

    // Red arc (upper-left)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        -2.0, 1.55, false, paint);

    // Yellow arc (lower-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        2.55, 0.9, false, paint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        1.75, 0.82, false, paint);

    // Horizontal bar of the 'G'
    paint
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(cx * 0.9, cy - r * 0.13, r, r * 0.27),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
