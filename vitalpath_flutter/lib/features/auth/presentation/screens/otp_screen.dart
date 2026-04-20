import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) { t.cancel(); return; }
      setState(() => _resendCountdown--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(int idx, String val) {
    if (val.length > 1) {
      // Handle paste
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < digits.length && (idx + i) < 6; i++) {
        _controllers[idx + i].text = digits[i];
      }
      if (idx + digits.length < 6) _focusNodes[idx + digits.length].requestFocus();
      else _focusNodes[5].requestFocus();
    } else if (val.isNotEmpty) {
      if (idx < 5) _focusNodes[idx + 1].requestFocus();
      else _focusNodes[5].requestFocus();
    }
    if (_otp.length == 6) _verify();
  }

  void _onKeyDown(int idx, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[idx].text.isEmpty && idx > 0) {
      _focusNodes[idx - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    if (_otp.length \!= 6) return;
    setState(() { _loading = true; _error = null; });
    HapticFeedback.mediumImpact();

    final err = await ref.read(authStateProvider.notifier)
        .verifyOtp(phone: widget.phone, otp: _otp);

    if (\!mounted) return;
    setState(() => _loading = false);
    if (err \!= null) {
      HapticFeedback.vibrate();
      setState(() => _error = err);
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } else {
      HapticFeedback.heavyImpact();
      context.go(AppConstants.routeHome);
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    setState(() { _resendCountdown = 60; _error = null; });
    _startCountdown();
    await ref.read(authStateProvider.notifier).sendOtp(widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: () => context.pop()),
        title: const Text('Verify Phone'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.sms_rounded, color: AppColors.primary, size: 28),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            const Text('Enter verification code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            RichText(text: TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.text3, height: 1.6),
              children: [
                const TextSpan(text: 'Sent to '),
                TextSpan(text: widget.phone, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text2)),
              ],
            )),
            const SizedBox(height: 32),

            // OTP boxes
            Row(
              children: List.generate(6, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 5 ? 10 : 0),
                  child: RawKeyboardListener(
                    focusNode: FocusNode(),
                    onKey: (e) => _onKeyDown(i, e),
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _controllers[i].text.isNotEmpty ? AppColors.primary : AppColors.border,
                            width: _controllers[i].text.isNotEmpty ? 2 : 1.5,
                          ),
                        ),
                        fillColor: _controllers[i].text.isNotEmpty ? AppColors.primaryLight : Colors.white,
                        filled: true,
                      ),
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  ),
                ),
              )),
            ).animate().slideY(begin: 0.05, duration: 400.ms, curve: Curves.easeOut),

            if (_error \!= null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.error_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error\!, style: const TextStyle(fontSize: 13, color: AppColors.error))),
                ]),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || _otp.length < 6) ? null : _verify,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Verify & Continue'),
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _resendCountdown == 0 ? _resend : null,
                child: Text(
                  _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend code',
                  style: TextStyle(color: _resendCountdown == 0 ? AppColors.primary : AppColors.text3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
