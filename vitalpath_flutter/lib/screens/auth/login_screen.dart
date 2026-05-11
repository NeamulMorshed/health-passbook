import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle, AppNotification, Timer;
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

  // Email form state
  bool _showEmailForm = false;
  bool _isRegisterMode = false;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Fix Low — TapGestureRecognizer lifecycle management.
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.parse('https://vitalpath.health/terms');
        if (await canLaunchUrl(uri)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
    _privacyTap = TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.parse('https://vitalpath.health/privacy');
        if (await canLaunchUrl(uri)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  // ── Google sign-in ──────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });

    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (!mounted) return;

    _handleResult(result);
  }

  // ── Email sign-in / register ────────────────────────────────────────────────

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final repo = ref.read(authRepositoryProvider);

    final result = _isRegisterMode
        ? await repo.registerWithEmail(email, password)
        : await repo.signInWithEmail(email, password);

    if (!mounted) return;

    // For new email registrations, mirror the Google new-user flow.
    if (result is AuthNewUser && widget.userType != null) {
      final newUser = AppUser(
        uid: result.uid,
        name: result.displayName ?? email.split('@').first,
        phone: '',
        userType:
            widget.userType == 'doctor' ? UserType.doctor : UserType.patient,
        createdAt: DateTime.now(),
      );
      try {
        await repo.createProfile(newUser);
      } catch (e) {
        if (mounted) setState(() { _loading = false; _error = 'Failed to create profile. Please try again.'; });
        return;
      }
      if (!mounted) return;
      _navigateForUser(newUser);
      return;
    }

    _handleResult(result);
  }

  void _handleResult(AuthResult result) {
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
          ref.read(authRepositoryProvider).createProfile(newUser).then((_) {
            if (mounted) _navigateForUser(newUser);
          }).catchError((e) {
            if (mounted) setState(() { _loading = false; _error = 'Failed to create profile. Please try again.'; });
          });
        } else {
          context.go('/user-select');
        }

      case AuthCancelled():
        setState(() => _loading = false);

      case AuthFailure(:final message):
        setState(() { _loading = false; _error = message; });
    }
  }

  void _navigateForUser(AppUser user) async {
    // Fix H7 — clear loading before navigating so the overlay is removed.
    if (mounted) setState(() => _loading = false);

    if (user.userType == UserType.doctor) {
      if (!user.onboardingComplete) {
        if (mounted) context.go('/doc/onboarding/profile');
      } else {
        if (mounted) context.go('/doc/dashboard');
      }
    } else if (!user.onboardingComplete) {
      if (mounted) context.go('/onboarding/permissions');
    } else {
      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      if (!mounted) return;
      context.go(biometricEnabled ? '/auth/faceid' : '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _loading,
          message: 'Signing in…',
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // ── Brand icon ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
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

                // ── Heading ──────────────────────────────────────────────────
                const Text(
                  'Welcome to\nOmra',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
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
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Error banner ─────────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Google button ────────────────────────────────────────────
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
                        _GoogleGlyph(),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Or divider ───────────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground.withValues(alpha: 0.7)),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ]),

                const SizedBox(height: 16),

                // ── Email form (toggle) ──────────────────────────────────────
                if (!_showEmailForm)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _showEmailForm = true;
                        _error = null;
                      }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email_outlined,
                              size: 18, color: AppColors.foreground),
                          SizedBox(width: 12),
                          Text(
                            'Continue with Email',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // ── Email form ─────────────────────────────────────────────
                  Text(
                    _isRegisterMode ? 'Create account' : 'Sign in with email',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground),
                  ),
                  const SizedBox(height: 14),
                  Form(
                    key: _formKey,
                    child: Column(children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                              .hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            _loading ? null : _submitEmail(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Lock(width: 20, height: 20),
                          suffixIcon: IconButton(
                            icon: _obscurePassword
                                ? const Eye(width: 20, height: 20)
                                : const EyeClosed(width: 20, height: 20),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (_isRegisterMode && v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitEmail,
                      child: Text(
                        _isRegisterMode ? 'Create Account' : 'Sign In',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      _isRegisterMode
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        _error = null;
                        _formKey.currentState?.reset();
                      }),
                      child: Text(
                        _isRegisterMode ? 'Sign in' : 'Register',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _showEmailForm = false;
                        _error = null;
                        _emailCtrl.clear();
                        _passwordCtrl.clear();
                      }),
                      child: const Text(
                        '← Back',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Terms ────────────────────────────────────────────────────
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground.withValues(alpha: 0.7),
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
                          recognizer: _termsTap,
                        ),
                        const TextSpan(text: ' & '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _privacyTap,
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

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        -0.45, 2.45, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        -2.0, 1.55, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        2.55, 0.9, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        1.75, 0.82, false, paint);

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
