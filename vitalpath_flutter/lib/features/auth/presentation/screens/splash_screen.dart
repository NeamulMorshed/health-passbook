import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  int _page = 0;
  late AnimationController _ringController;

  final _pages = const [
    _SplashPage(
      step: 'TRACK',
      headline: 'Your Health,\nAll in One Place',
      body: 'Log medications, monitor vitals, and stay on top of your care plan — all from your pocket.',
      color: AppColors.primary,
    ),
    _SplashPage(
      step: 'CONNECT',
      headline: 'Stay in Sync\nWith Your Doctor',
      body: 'Real-time prescription updates, verified dosages, and direct communication with your care team.',
      color: AppColors.secondary,
    ),
    _SplashPage(
      step: 'THRIVE',
      headline: 'Smart Alerts,\nAlways Safe',
      body: 'Duplicate dose detection, timezone-aware scheduling, and intelligent reminders keep you safe.',
      color: AppColors.warning,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (\!mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState.valueOrNull?.isLoggedIn ?? false) {
      context.go(AppConstants.routeHome);
    }
  }

  @override
  void dispose() { _ringController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                _buildIllustration(page),
                const Spacer(),
                _buildDots(),
                const SizedBox(height: 20),
                Text(page.step,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                      letterSpacing: 2.4, color: Color(0x66FFFFFF))),
                const SizedBox(height: 10),
                Text(page.headline,
                  key: ValueKey(_page),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
                const SizedBox(height: 14),
                Text(page.body,
                  key: ValueKey('body$_page'),
                  style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.55), height: 1.65)),
                const SizedBox(height: 32),
                _buildActions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(_SplashPage page) {
    return Center(
      child: SizedBox(
        width: 260, height: 240,
        child: AnimatedBuilder(
          animation: _ringController,
          builder: (_, __) => CustomPaint(
            painter: _SplashIlloPainter(
              progress: _ringController.value,
              page: _page,
              color: page.color,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildDots() => Row(
    children: List.generate(_pages.length, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _page == i ? 22 : 7,
      height: 7,
      margin: const EdgeInsets.only(right: 7),
      decoration: BoxDecoration(
        color: _page == i ? AppColors.primary : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    )),
  );

  Widget _buildActions() {
    final isLast = _page == _pages.length - 1;
    return Row(
      children: [
        if (\!isLast)
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go(AppConstants.routeLogin),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.6),
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Text('Skip'),
            ),
          ),
        if (\!isLast) const SizedBox(width: 12),
        Expanded(
          flex: isLast ? 1 : 1,
          child: ElevatedButton(
            onPressed: isLast
                ? () => context.go(AppConstants.routeLogin)
                : () => setState(() => _page++),
            child: Text(isLast ? 'Get Started' : 'Next'),
          ),
        ),
      ],
    );
  }
}

class _SplashPage {
  final String step, headline, body;
  final Color color;
  const _SplashPage({required this.step, required this.headline, required this.body, required this.color});
}

class _SplashIlloPainter extends CustomPainter {
  final double progress;
  final int page;
  final Color color;
  _SplashIlloPainter({required this.progress, required this.page, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ambient glow ring
    final glowPaint = Paint()
      ..color = color.withOpacity(0.08 + 0.04 * (1 - (progress - 0.5).abs() * 2))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 100 + progress * 20, glowPaint);

    // Animated arc ring
    final ringPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const import = 3.14159265 * 2;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: 80),
      -import / 4 + progress * import,
      import * 0.7,
      false, ringPaint,
    );

    // Inner circle
    final centerPaint = Paint()..color = color.withOpacity(0.15);
    canvas.drawCircle(Offset(cx, cy), 56, centerPaint);

    // Icon-like cross (health symbol)
    final iconPaint = Paint()..color = color..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 22), Offset(cx, cy + 22), iconPaint);
    canvas.drawLine(Offset(cx - 22, cy), Offset(cx + 22, cy), iconPaint);

    // Floating dots
    for (var i = 0; i < 5; i++) {
      final angle = (progress * import) + (i * import / 5);
      final r = 108.0;
      final dx = cx + r * (import * angle / import);
      final dy = cy + r * (import * angle / import);
      canvas.drawCircle(
        Offset(cx + r * 0.9 * (i % 2 == 0 ? 1 : -1), cy + (i * 28.0 - 56)),
        3 + i.toDouble(),
        Paint()..color = color.withOpacity(0.25 + progress * 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_SplashIlloPainter old) => old.progress \!= progress || old.page \!= page;
}
