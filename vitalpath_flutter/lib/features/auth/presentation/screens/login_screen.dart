import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _phoneController.dispose(); super.dispose(); }

  Future<void> _sendOtp() async {
    if (\!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    HapticFeedback.mediumImpact();

    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.sendOtp(_phoneController.text.trim());

    if (\!mounted) return;
    setState(() => _loading = false);
    final state = ref.read(authStateProvider);
    if (state.hasError) {
      setState(() => _error = state.error?.toString());
    } else {
      context.push(AppConstants.routeOtp, extra: _phoneController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ─────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                    ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 16),
                    const Text('Welcome to\nVitalPath',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                    const SizedBox(height: 8),
                    Text('Your personal health companion',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.65))),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          // ── Form body ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('PHONE NUMBER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1, color: AppColors.text3)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 15,
                      decoration: const InputDecoration(
                        hintText: '+1 555 000 0000',
                        prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primary),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.length < 8) return 'Enter a valid phone number';
                        return null;
                      },
                    ).animate().slideX(begin: -0.05, duration: 400.ms, curve: Curves.easeOut),

                    if (_error \!= null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_rounded, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error\!, style: const TextStyle(fontSize: 13, color: AppColors.error))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _sendOtp,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Send Verification Code'),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: Text('By continuing, you agree to our\nTerms of Service & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.text3, height: 1.6)),
                    ),

                    const SizedBox(height: 40),
                    // Demo hint
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_rounded, color: AppColors.primary, size: 16),
                              SizedBox(width: 8),
                              Text('Demo Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Enter any 10-digit number and use OTP 123456',
                            style: TextStyle(fontSize: 12, color: AppColors.primaryDark.withOpacity(0.75))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
