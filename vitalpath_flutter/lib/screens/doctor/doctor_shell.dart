import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class DoctorShell extends StatelessWidget {
  final Widget child;
  const DoctorShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/doc/dashboard'),
    _TabItem(icon: Icons.people_rounded, label: 'Patients', route: '/doc/patients'),
    _TabItem(icon: Icons.calendar_month_rounded, label: 'Appointments', route: '/doc/appointments'),
    _TabItem(icon: Icons.person_rounded, label: 'Profile', route: '/doc/profile'),
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
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => context.go(_tabs[i].route),
          selectedItemColor: AppColors.doctorPrimary,
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
