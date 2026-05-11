import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

// Shows a 4-step coach-mark tour as a bottom sheet the first time the
// patient lands on the Home screen after completing onboarding.
// The guard is a SharedPreferences flag so it only fires once.

Future<void> maybeShowOnboardingTour(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(AppConstants.prefOnboardingTourDone) == true) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TourSheet(),
  );

  await prefs.setBool(AppConstants.prefOnboardingTourDone, true);
}

class _TourSheet extends StatefulWidget {
  const _TourSheet();
  @override
  State<_TourSheet> createState() => _TourSheetState();
}

class _TourSheetState extends State<_TourSheet> {
  final _ctrl = PageController();
  int _page = 0;

  static const _steps = [
    _TourStep(
      icon: Icons.favorite_rounded,
      color: AppColors.primary,
      title: 'Your daily health summary',
      body: 'The Home screen shows you exactly how your day is going — medicines taken, meals logged, steps walked, and upcoming appointments.',
    ),
    _TourStep(
      icon: Icons.medication_outlined,
      color: AppColors.success,
      title: 'Log medicines and meals',
      body: 'Tap the Care tab to add your medicines, log breakfast, lunch and dinner, and see your family member\'s health at a glance.',
    ),
    _TourStep(
      icon: Icons.directions_walk_rounded,
      color: Color(0xFF0EA5E9),
      title: 'Track your activity',
      body: 'Use Activity to track walks, runs, yoga, gym sessions and more. See a weekly chart of your progress over time.',
    ),
    _TourStep(
      icon: Icons.local_hospital_rounded,
      color: AppColors.primary,
      title: 'Connect with doctors',
      body: 'Find and connect with your doctor from My Doctors. They can send you prescriptions and approve appointments directly in the app.',
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _steps.length - 1) {
      setState(() => _page++);
      _ctrl.animateToPage(_page,
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_page];
    final isLast = _page == _steps.length - 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Page content (fixed height to prevent layout shifts)
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _ctrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _steps.length,
              itemBuilder: (_, i) {
                final s = _steps[i];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, size: 36, color: s.color),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                          height: 1.5),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _page ? step.color : AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),

          const SizedBox(height: 24),

          // Buttons
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: step.color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isLast ? 'Get started' : 'Next',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip tour',
                style: TextStyle(
                    color: AppColors.mutedForeground)),
          ),
        ]),
      ),
    );
  }
}

class _TourStep {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _TourStep(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});
}
