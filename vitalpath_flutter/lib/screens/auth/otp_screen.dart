import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String userType;
  const OtpScreen({super.key, required this.phone, required this.userType});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _nodes[0].requestFocus();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onChanged(int i, String v) {
    if (v.length == 1 && i < 5) _nodes[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
    if (_otp.length == 6) _verify();
  }

  void _verify() async {
    final ok = await ref.read(otpProvider.notifier).verifyOtp(_otp);
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, 'Incorrect OTP. Please try again.', isError: true);
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
      return;
    }
    // Check if user profile exists
    final firebaseUser = ref.read(authServiceProvider).currentUser;
    if (firebaseUser == null) return;
    final user = await ref.read(authServiceProvider).getUserProfile(firebaseUser.uid);
    if (user == null) {
      // New user — create profile + onboard
      await ref.read(authServiceProvider).createUserProfile(AppUser(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? '',
        phone: widget.phone,
        userType: widget.userType == 'doctor' ? UserType.doctor : UserType.patient,
        createdAt: DateTime.now(),
      ));
      if (widget.userType == 'doctor') {
        context.go('/doc/dashboard');
      } else {
        context.go('/onboarding/permissions');
      }
    } else {
      context.go('/auth/faceid');
    }
  }

  void _resend() {
    setState(() => _resendSeconds = 60);
    _startTimer();
    ref.read(otpProvider.notifier).sendOtp(widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: state.isLoading,
          message: 'Verifying...',
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.foreground),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.sms_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 20),
                const Text('Enter OTP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
                const SizedBox(height: 8),
                Text('Code sent to ${widget.phone}', style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                const SizedBox(height: 40),

                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _OtpBox(
                    controller: _ctrls[i],
                    focusNode: _nodes[i],
                    onChanged: (v) => _onChanged(i, v),
                  )),
                ),
                const SizedBox(height: 36),

                GradientButton(label: 'Verify', onPressed: _otp.length == 6 ? _verify : null),
                const SizedBox(height: 24),

                Center(
                  child: _resendSeconds > 0
                      ? Text('Resend in $_resendSeconds s', style: const TextStyle(color: AppColors.mutedForeground, fontFamily: 'Inter'))
                      : TextButton(
                          onPressed: _resend,
                          child: const Text('Resend OTP', style: TextStyle(color: AppColors.primary, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 54,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.muted,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
