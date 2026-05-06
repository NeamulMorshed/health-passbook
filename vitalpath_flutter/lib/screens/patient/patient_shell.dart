import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class PatientShell extends StatelessWidget {
  final Widget child;
  const PatientShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.home_rounded, label: 'Home', route: '/home'),
    _TabItem(icon: Icons.medication_rounded, label: 'Care', route: '/care'),
    _TabItem(icon: Icons.people_rounded, label: 'Circle', route: '/care-circle'),
    _TabItem(icon: Icons.calendar_today_rounded, label: 'Visits', route: '/appointments'),
    _TabItem(icon: Icons.person_rounded, label: 'Profile', route: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    // Longest-match first: check exact or prefix, but don't let '/care'
    // steal a match from '/care-circle'.
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
          items: _tabs.map((t) => BottomNavigationBarItem(
            icon: Icon(t.icon),
            label: t.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String route;
  const _TabItem({required this.icon, required this.label, required this.route});
}
