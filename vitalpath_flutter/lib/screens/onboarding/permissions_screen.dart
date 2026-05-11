import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle, AppNotification, Timer;
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  int _step = 0;

  final _perms = [
    _PermData(
      icon: const MapPin(width: 50, height: 50, color: AppColors.success),
      color: AppColors.success,
      title: 'Location Access',
      subtitle: 'Track your walks and outdoor activities with GPS for accurate distance measurement.',
      why: 'So we can measure walking distance accurately',
      permission: Permission.location,
    ),
    _PermData(
      icon: const Camera(width: 50, height: 50, color: AppColors.primary),
      color: AppColors.primary,
      title: 'Camera & Photos',
      subtitle: 'Take photos of your meals and prescriptions to keep detailed health records.',
      why: 'So you can scan prescriptions and log meals with photos',
      permission: Permission.camera,
    ),
    _PermData(
      icon: const Bell(width: 50, height: 50, color: AppColors.warning),
      color: AppColors.warning,
      title: 'Medication Reminders',
      subtitle: 'Get notified when it\'s time to take your medicine. Never miss a dose again.',
      why: 'So you never miss a dose or appointment',
      permission: Permission.notification,
    ),
  ];

  void _allow() async {
    final perm = _perms[_step].permission;
    if (perm != null) await perm.request();
    // Fix H — mounted check after async permission request.
    if (!mounted) return;
    _next();
  }

  void _next() {
    if (_step < _perms.length - 1) {
      setState(() => _step++);
    } else {
      context.go('/onboarding/health-profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _perms[_step];
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              // Fix H — Back button on step 0 (returns to /user-select).
              if (_step == 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/user-select'),
                  ),
                ),
              const SizedBox(height: 8),
              // Progress
              Row(
                children: List.generate(_perms.length, (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < _perms.length - 1 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= _step ? data.color : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(color: data.color.withValues(alpha:0.12), shape: BoxShape.circle),
                child: Center(child: data.icon),
              ),
              const SizedBox(height: 36),
              Text(data.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.foreground)),
              const SizedBox(height: 12),
              Text(data.subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.mutedForeground, height: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: data.color.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: data.color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data.why, style: TextStyle(fontSize: 13, color: data.color))),
                ]),
              ),
              const Spacer(),
              GradientButton(label: 'Allow ${data.title}', colors: [data.color, data.color.withValues(alpha:0.8)], onPressed: _allow),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _next,
                child: const Text('Not now', style: TextStyle(color: AppColors.mutedForeground)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermData {
  final Widget icon;
  final Color color;
  final String title;
  final String subtitle;
  final String why;
  final Permission? permission;
  const _PermData({required this.icon, required this.color, required this.title, required this.subtitle, required this.why, this.permission});
}
