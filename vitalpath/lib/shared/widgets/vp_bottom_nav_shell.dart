import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Bottom navigation shell for the main app (Dashboard, Meds, Activity, Doctor, Profile).
class VpBottomNavShell extends StatelessWidget {
  final Widget child;

  const VpBottomNavShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  route: AppConstants.routeDashboard,
                  isActive: location == AppConstants.routeDashboard,
                ),
                _NavItem(
                  icon: Icons.medication_outlined,
                  activeIcon: Icons.medication_rounded,
                  label: 'Meds',
                  route: AppConstants.routeMedicineList,
                  isActive: location.startsWith(AppConstants.routeMedicineList),
                ),
                _NavItem(
                  icon: Icons.directions_walk_outlined,
                  activeIcon: Icons.directions_walk_rounded,
                  label: 'Activity',
                  route: AppConstants.routeActivity,
                  isActive: location.startsWith(AppConstants.routeActivity),
                ),
                _NavItem(
                  icon: Icons.restaurant_outlined,
                  activeIcon: Icons.restaurant_rounded,
                  label: 'Nutrition',
                  route: AppConstants.routeNutrition,
                  isActive: location.startsWith(AppConstants.routeNutrition),
                ),
                _NavItem(
                  icon: Icons.medical_services_outlined,
                  activeIcon: Icons.medical_services_rounded,
                  label: 'Doctor',
                  route: AppConstants.routeDoctorSync,
                  isActive: location.startsWith(AppConstants.routeDoctorSync),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
