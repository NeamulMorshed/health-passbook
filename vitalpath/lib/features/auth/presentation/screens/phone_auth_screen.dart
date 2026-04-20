import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

/// Phone number entry screen — first step of OTP auth (SRS §3.1).
class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _countryCode = '+880'; // Bangladesh default (adjust per market)

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = '$_countryCode${_phoneController.text.trim()}';
    try {
      await ref.read(phoneAuthNotifierProvider.notifier).sendOtp(phone);
      if (mounted) {
        context.push(AppConstants.routeOtpVerify, extra: phone);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(phoneAuthNotifierProvider);
    final isLoading = authStatus == OtpFlowStatus.sendingOtp;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Back button
              IconButton(
                onPressed: () => context.go(AppConstants.routeOnboarding),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                padding: EdgeInsets.zero,
                color: AppColors.textPrimary,
              ),

              const SizedBox(height: 32),

              // Header
              const Text(
                'Enter your\nphone number',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

              const SizedBox(height: 12),

              const Text(
                "We'll send a verification code to confirm your number.",
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 48),

              // Phone number form
              Form(
                key: _formKey,
                child: Row(
                  children: [
                    // Country code picker
                    GestureDetector(
                      onTap: () => _showCountryPicker(),
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _countryCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: '01XXXXXXXXX',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.length < 7) {
                            return 'Invalid phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 16),

              Text(
                'Standard message rates may apply.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary.withOpacity(0.8),
                ),
              ),

              const Spacer(),

              // CTA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _sendOtp,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Verification Code'),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CountryPickerSheet(
        selected: _countryCode,
        onSelected: (code) {
          setState(() => _countryCode = code);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;

  const _CountryPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  static const _countries = [
    ('+880', 'Bangladesh'),
    ('+1', 'United States'),
    ('+44', 'United Kingdom'),
    ('+91', 'India'),
    ('+971', 'UAE'),
    ('+60', 'Malaysia'),
    ('+65', 'Singapore'),
    ('+61', 'Australia'),
    ('+49', 'Germany'),
    ('+33', 'France'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Select Country Code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          ..._countries.map((c) => ListTile(
                leading: Text(
                  c.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
                ),
                title: Text(c.$2),
                trailing: c.$1 == selected
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () => onSelected(c.$1),
              )),
        ],
      ),
    );
  }
}
