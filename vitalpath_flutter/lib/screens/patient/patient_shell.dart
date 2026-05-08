import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class PatientShell extends StatelessWidget {
  final Widget child;
  const PatientShell({super.key, required this.child});

  // Home · Medicines · Vitals · Appointments · Profile
  // "Care" renamed to "Medicines" — clearer daily-use label.
  // "Vitals" promoted from full-screen push to a first-class tab.
  // "Circle" removed from nav — accessible via Profile → Care Circle.
  static const _tabs = [
    _TabItem(
      icon: Icons.home_rounded,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      route: '/home',
    ),
    _TabItem(
      icon: Icons.medication_outlined,
      activeIcon: Icons.medication_rounded,
      label: 'Medicines',
      route: '/care',
    ),
    _TabItem(
      icon: Icons.monitor_heart_outlined,
      activeIcon: Icons.monitor_heart_rounded,
      label: 'Vitals',
      route: '/vitals',
    ),
    _TabItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Appointments',
      route: '/appointments',
    ),
    _TabItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      route: '/profile',
    ),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    int best = 0;
    int bestLen = 0;
    for (int i = 0; i < _tabs.length; i++) {
      final route = _tabs[i].route;
      if (loc == route || loc.startsWith('$route/')) {
        if (route.length > bestLen) {
          best = i;
          bestLen = route.length;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => context.go(_tabs[i].route),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.mutedForeground,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 11,
          ),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: List.generate(_tabs.length, (i) {
            final t = _tabs[i];
            final active = i == idx;
            return BottomNavigationBarItem(
              icon: Icon(active ? t.activeIcon : t.icon),
              label: t.label,
            );
          }),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
