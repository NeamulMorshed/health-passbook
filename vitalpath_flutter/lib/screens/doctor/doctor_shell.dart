import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_theme.dart';

class DoctorShell extends StatelessWidget {
  final Widget child;
  const DoctorShell({super.key, required this.child});

  static const _kSize = 24.0;

  static final _tabs = [
    _TabItem(
      icon: HugeIcon(
          icon: HugeIcons.strokeRoundedChartIncrease,
          color: AppColors.textTertiary,
          size: _kSize),
      selectedIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedChartIncrease,
          color: AppColors.primary,
          size: _kSize),
      label: 'Dashboard',
      route: '/doc/dashboard',
    ),
    _TabItem(
      icon: HugeIcon(
          icon: HugeIcons.strokeRoundedGroup,
          color: AppColors.textTertiary,
          size: _kSize),
      selectedIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedGroup,
          color: AppColors.primary,
          size: _kSize),
      label: 'Patients',
      route: '/doc/patients',
    ),
    _TabItem(
      icon: HugeIcon(
          icon: HugeIcons.strokeRoundedCalendar01,
          color: AppColors.textTertiary,
          size: _kSize),
      selectedIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedCalendar01,
          color: AppColors.primary,
          size: _kSize),
      label: 'Visits',
      route: '/doc/appointments',
    ),
    _TabItem(
      icon: HugeIcon(
          icon: HugeIcons.strokeRoundedUser,
          color: AppColors.textTertiary,
          size: _kSize),
      selectedIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedUser,
          color: AppColors.primary,
          size: _kSize),
      label: 'Profile',
      route: '/doc/profile',
    ),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].route)) return i;
    }
    return 0;
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
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_tabs[i].route),
          backgroundColor: AppColors.surface,
          elevation: 0,
          destinations: _tabs
              .map((t) => NavigationDestination(
                    icon: t.icon,
                    selectedIcon: t.selectedIcon,
                    label: t.label,
                  ))
              .toList(),
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
  const _TabItem(
      {required this.icon,
      required this.selectedIcon,
      required this.label,
      required this.route});
}
