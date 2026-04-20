import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shell scaffolds — wrap bottom nav around screen content
// ─────────────────────────────────────────────────────────────────────────────

class PatientShellScaffold extends StatelessWidget {
  final Widget child;
  const PatientShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _patientIndexFromRoute(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: _VitalpathBottomNav(
        currentIndex: idx,
        onTap: (i) => _navigatePatient(context, i),
        items: const [
          _NavItem(icon: Icons.home_rounded, label: 'Home'),
          _NavItem(icon: Icons.medication_rounded, label: 'Meds'),
          _NavItem(icon: Icons.favorite_rounded, label: 'Activity'),
          _NavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        fabIcon: Icons.add_rounded,
        onFabTap: () => _showQuickLog(context),
      ),
    );
  }

  int _patientIndexFromRoute(String location) {
    if (location.startsWith(AppConstants.routeMedication)) return 1;
    if (location.startsWith(AppConstants.routeActivity))   return 2;
    if (location.startsWith(AppConstants.routeProfile))    return 3;
    return 0;
  }

  void _navigatePatient(BuildContext ctx, int i) {
    HapticFeedback.lightImpact();
    switch (i) {
      case 0: ctx.go(AppConstants.routeHome);       break;
      case 1: ctx.go(AppConstants.routeMedication); break;
      case 2: ctx.go(AppConstants.routeActivity);   break;
      case 3: ctx.go(AppConstants.routeProfile);    break;
    }
  }

  void _showQuickLog(BuildContext ctx) {
    HapticFeedback.mediumImpact();
    // FAB opens quick log bottom sheet — implemented in medication provider
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QuickLogSheet(),
    );
  }
}

class DoctorShellScaffold extends StatelessWidget {
  final Widget child;
  const DoctorShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = location.startsWith(AppConstants.routeDoctorSync) ? 1 : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: _VitalpathBottomNav(
        currentIndex: idx,
        onTap: (i) {
          HapticFeedback.lightImpact();
          if (i == 0) context.go(AppConstants.routeDoctorRoster);
          if (i == 1) context.go(AppConstants.routeDoctorSync);
        },
        items: const [
          _NavItem(icon: Icons.people_rounded, label: 'Roster'),
          _NavItem(icon: Icons.sync_rounded,   label: 'Sync'),
        ],
      ),
    );
  }
}

// ── Shared Bottom Nav ─────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _VitalpathBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;
  final IconData? fabIcon;
  final VoidCallback? onFabTap;

  const _VitalpathBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.fabIcon,
    this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Left items (before FAB if present)
              ...List.generate(
                fabIcon \!= null ? (items.length / 2).ceil() : items.length,
                (i) => Expanded(child: _NavButton(item: items[i], isActive: currentIndex == i, onTap: () => onTap(i))),
              ),
              if (fabIcon \!= null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _FabButton(icon: fabIcon\!, onTap: onFabTap\!),
                ),
                ...List.generate(
                  (items.length / 2).floor(),
                  (i) {
                    final idx = (items.length / 2).ceil() + i;
                    return Expanded(child: _NavButton(item: items[idx], isActive: currentIndex == idx, onTap: () => onTap(idx)));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.isActive, required this.onTap});
  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? AppColors.primary : AppColors.text3;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.item.icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(widget.item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FabButton({required this.icon, required this.onTap});
  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.secondaryGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 4))],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _QuickLogSheet extends StatelessWidget {
  const _QuickLogSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 8, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Text('Quick Log', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Select a medication to mark as taken', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
