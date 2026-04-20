import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

/// OTP verification screen — 6-digit code entry with auto-submit.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpVerifyScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify(String otp) async {
    if (otp.length < 6) return;
    setState(() => _isVerifying = true);

    try {
      await ref.read(phoneAuthNotifierProvider.notifier).verifyOtp(
            phoneNumber: widget.phoneNumber,
            otp: otp,
          );

      if (mounted) {
        final user = ref.read(currentUserProvider);
        // Check if user has completed onboarding
        context.go(AppConstants.routeHealthProfile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid code. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        _otpController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),

              const Text(
                'Verify your\nnumber',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 12),

              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit code sent to '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 48),

              // OTP Input
              Center(
                child: Pinput(
                  controller: _otpController,
                  length: 6,
                  autofocus: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  ),
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.primaryLight, width: 1.5),
                    ),
                  ),
                  onCompleted: _verify,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 32),

              // Resend option
              Center(
                child: TextButton(
                  onPressed: () async {
                    await ref
                        .read(phoneAuthNotifierProvider.notifier)
                        .sendOtp(widget.phoneNumber);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code resent!')),
                      );
                    }
                  },
                  child: const Text("Didn't receive a code? Resend"),
                ),
              ),

              if (_isVerifying) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
