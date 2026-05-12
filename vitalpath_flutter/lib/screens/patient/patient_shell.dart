import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart';
import '../../core/theme/app_theme.dart';

class PatientShell extends StatelessWidget {
  final Widget child;
  const PatientShell({super.key, required this.child});

  static const _kSize = 24.0;

  static final _tabs = [
    _TabItem(
      icon:         Home(width: _kSize, height: _kSize, color: AppColors.textTertiary),
      selectedIcon: Home(width: _kSize, height: _kSize, color: AppColors.primary),
      label: 'Home', route: '/home',
    ),
    _TabItem(
      icon:         PharmacyCrossCircle(width: _kSize, height: _kSize, color: AppColors.textTertiary),
      selectedIcon: PharmacyCrossCircle(width: _kSize, height: _kSize, color: AppColors.primary),
      label: 'Medicines', route: '/care',
    ),
    _TabItem(
      icon:         Activity(width: _kSize, height: _kSize, color: AppColors.textTertiary),
      selectedIcon: Activity(width: _kSize, height: _kSize, color: AppColors.primary),
      label: 'Vitals', route: '/vitals',
    ),
    _TabItem(
      icon:         Calendar(width: _kSize, height: _kSize, color: AppColors.textTertiary),
      selectedIcon: Calendar(width: _kSize, height: _kSize, color: AppColors.primary),
      label: 'Visits', route: '/appointments',
    ),
    _TabItem(
      icon:         User(width: _kSize, height: _kSize, color: AppColors.textTertiary),
      selectedIcon: User(width: _kSize, height: _kSize, color: AppColors.primary),
      label: 'Profile', route: '/profile',
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
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          boxShadow: [BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          )],
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_tabs[i].route),
          backgroundColor: AppColors.surface,
          elevation: 0,
          destinations: _tabs.map((t) => NavigationDestination(
            icon: t.icon,
            selectedIcon: t.selectedIcon,
            label: t.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final String route;
  const _TabItem({required this.icon, required this.selectedIcon, required this.label, required this.route});
}
