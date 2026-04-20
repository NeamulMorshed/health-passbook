import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/doctor_provider.dart';

class DoctorSyncScreen extends ConsumerStatefulWidget {
  const DoctorSyncScreen({super.key});
  @override
  ConsumerState<DoctorSyncScreen> createState() => _DoctorSyncScreenState();
}

class _DoctorSyncScreenState extends ConsumerState<DoctorSyncScreen>
    with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  int _secondsLeft = AppConstants.syncCodeValiditySecs;
  late AnimationController _ringCtrl;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final session = ref.read(syncSessionProvider);
    _secondsLeft = session.remainingSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, AppConstants.syncCodeValiditySecs));
      if (_secondsLeft == 0) { t.cancel(); _regenerate(); }
    });
  }

  void _regenerate() {
    ref.read(syncSessionProvider.notifier).regenerate();
    setState(() => _secondsLeft = AppConstants.syncCodeValiditySecs);
    _startCountdown();
  }

  void _simulateConnect() {
    setState(() => _connected = true);
    _ringCtrl.forward();
    _countdownTimer?.cancel();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(syncSessionProvider.notifier).markConnected('mock_patient_id');
        context.push('/doctor/patient/p1');
      }
    });
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync code copied: ${code.split('').join(' ')}'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTime(int secs) =>
      '${(secs / 60).floor()}:${(secs % 60).toString().padLeft(2, '0')}';

  double get _ringProgress => _secondsLeft / AppConstants.syncCodeValiditySecs;
  Color get _ringColor => _secondsLeft < 60 ? AppColors.error : AppColors.primary;

  @override
  void dispose() { _countdownTimer?.cancel(); _ringCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(syncSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => context.go(AppConstants.routeDoctorRoster),
            ),
            title: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Doctor Portal', style: TextStyle(fontSize: 11, color: AppColors.text3, fontWeight: FontWeight.w600, letterSpacing: 1)),
              Text('Patient Sync', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Status card
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _connected ? _ConnectedCard() : _WaitingCard(),
                ).animate().fadeIn(),

                const SizedBox(height: 14),

                // Code display card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadows,
                  ),
                  child: Column(children: [
                    const Text('SYNC CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 1.2, color: AppColors.text3)),
                    const SizedBox(height: 14),

                    // 6-box code display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: session.code.split('').map((digit) =>
                        Container(
                          width: 44, height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                          ),
                          child: Center(child: Text(digit,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary))),
                        ),
                      ).toList(),
                    ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 20),

                    // Countdown ring
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(
                        width: 56, height: 56,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: _ringProgress),
                          duration: const Duration(milliseconds: 800),
                          builder: (_, v, __) => CustomPaint(
                            painter: _CountdownRingPainter(progress: _ringProgress, color: _ringColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_formatTime(_secondsLeft),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                              color: _ringColor, fontFeatures: const [FontFeature.tabularFigures()])),
                        const Text('Code expires', style: TextStyle(fontSize: 11, color: AppColors.text3)),
                      ]),
                    ]),

                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => _copyCode(session.code),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _regenerate,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Regenerate'),
                      )),
                    ]),
                  ]),
                ).animate().fadeIn(duration: 400.ms, delay: 80.ms),

                const SizedBox(height: 14),

                // QR code card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadows,
                  ),
                  child: Column(children: [
                    const Text('Or scan QR code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text3)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: QrImageView(
                        data: 'vitalpath://sync/${session.code}',
                        version: QrVersions.auto,
                        size: 160,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.text1),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.text1),
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 400.ms, delay: 160.ms),

                const SizedBox(height: 14),

                // Demo button
                ElevatedButton.icon(
                  onPressed: _connected ? null : _simulateConnect,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Simulate Patient Scan'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: AppColors.secondary,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 240.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppColors.cardShadows,
    ),
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.smartphone_rounded, color: AppColors.primary, size: 30),
      ),
      const SizedBox(height: 14),
      const Text('Waiting for patient scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Ask your patient to open VitalPath and tap Sync with Doctor in their profile.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.text3, height: 1.6)),
    ]),
  );
}

class _ConnectedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.secondaryLight,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
    ),
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
      ),
      const SizedBox(height: 14),
      const Text('Patient connected!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.secondary)),
      const SizedBox(height: 8),
      const Text('Redirecting to patient view…', style: TextStyle(fontSize: 13, color: AppColors.text3)),
    ]),
  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut);
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CountdownRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = (size.width - 6) / 2;
    final bg = Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = 5;
    final fg = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, bg);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -3.14159 / 2, 2 * 3.14159 * progress, false, fg);
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) => old.progress != progress;
}
