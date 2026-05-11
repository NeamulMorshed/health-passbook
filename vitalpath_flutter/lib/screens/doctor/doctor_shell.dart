import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart';
import '../../core/theme/app_theme.dart';

class DoctorShell extends StatelessWidget {
  final Widget child;
  const DoctorShell({super.key, required this.child});

  static final _tabs = [
    _TabItem(icon: const StatsUpSquare(width: 22, height: 22), label: 'Dashboard',    route: '/doc/dashboard'),
    _TabItem(icon: const Group(width: 22, height: 22),         label: 'Patients',     route: '/doc/patients'),
    _TabItem(icon: const Calendar(width: 22, height: 22),      label: 'Appointments', route: '/doc/appointments'),
    _TabItem(icon: const User(width: 22, height: 22),          label: 'Profile',      route: '/doc/profile'),
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
            selectedIcon: t.icon,
            label: t.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final Widget icon;
  final String label;
  final String route;
  const _TabItem({required this.icon, required this.label, required this.route});
}
