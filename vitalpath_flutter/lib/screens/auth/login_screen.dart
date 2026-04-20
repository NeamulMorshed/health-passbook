import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedCountryCode = '+880';
  String _userType = 'patient';

  final _countryCodes = [
    _Country('BD', '+880', '🇧🇩'),
    _Country('US', '+1', '🇺🇸'),
    _Country('GB', '+44', '🇬🇧'),
    _Country('IN', '+91', '🇮🇳'),
    _Country('AU', '+61', '🇦🇺'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    if (\!_formKey.currentState\!.validate()) return;
    final phone = '$_selectedCountryCode${_phoneCtrl.text.trim()}';
    final otpState = ref.read(otpProvider);
    await ref.read(otpProvider.notifier).sendOtp(phone);
    if (\!mounted) return;
    final state = ref.read(otpProvider);
    if (state.error \!= null) {
      showAppSnack(context, state.error\!, isError: true);
    } else if (state.verificationId \!= null || state.verified) {
      context.push('/auth/otp', extra: {'phone': phone, 'userType': _userType});
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpProvider);
    // Read userType from route extras if available
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: otpState.isLoading,
          message: 'Sending OTP...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.go('/user-select'),
                    child: const Icon(Icons.arrow_back_rounded, color: AppColors.foreground),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: 20),
                  const Text('Enter your phone', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
                  const SizedBox(height: 8),
                  const Text('We\'ll send a verification code to confirm it\'s you.', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                  const SizedBox(height: 36),

                  // Country code + phone
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        // Country picker
                        GestureDetector(
                          onTap: _showCountryPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              children: [
                                Text(_countryCodes.firstWhere((c) => c.code == _selectedCountryCode).flag),
                                const SizedBox(width: 6),
                                Text(_selectedCountryCode, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.mutedForeground),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              hintText: '01XXXXXXXXX',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter phone number';
                              if (v.trim().length < 7) return 'Invalid phone number';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  GradientButton(
                    label: 'Send OTP',
                    onPressed: _sendOtp,
                    isLoading: otpState.isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: const TextStyle(color: AppColors.mutedForeground, fontFamily: 'Inter')),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),

                  // Google sign-in
                  OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                    label: const Text('Continue with Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Select Country', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          const SizedBox(height: 8),
          ..._countryCodes.map((c) => ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                title: Text(c.name, style: const TextStyle(fontFamily: 'Inter')),
                trailing: Text(c.code, style: const TextStyle(color: AppColors.mutedForeground, fontFamily: 'Inter')),
                onTap: () {
                  setState(() => _selectedCountryCode = c.code);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _signInWithGoogle() async {
    final result = await ref.read(authServiceProvider).signInWithGoogle();
    if (result == null || \!mounted) return;
    // Check if user profile exists
    final user = await ref.read(authServiceProvider).getUserProfile(result.user\!.uid);
    if (user == null) {
      // New user — need to create profile
      context.go('/onboarding/permissions');
    } else if (user.userType.name == 'doctor') {
      context.go('/doc/dashboard');
    } else {
      context.go('/home');
    }
  }
}

class _Country {
  final String name, code, flag;
  const _Country(this.name, this.code, this.flag);
}
