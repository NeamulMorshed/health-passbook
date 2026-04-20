import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class UserSelectScreen extends StatelessWidget {
  const UserSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 28),
              const Text('Welcome to\nVitalPath', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground, height: 1.2)),
              const SizedBox(height: 10),
              const Text('How are you using VitalPath today?', style: TextStyle(fontSize: 15, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              const SizedBox(height: 48),
              _RoleCard(
                icon: Icons.person_rounded,
                color: AppColors.primary,
                title: 'I\'m a Patient',
                subtitle: 'Track medicines, meals, activity\nand connect with your doctor',
                onTap: () => context.go('/auth/login', extra: {'userType': 'patient'}),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.medical_services_rounded,
                color: AppColors.doctorPrimary,
                title: 'I\'m a Doctor',
                subtitle: 'Manage patients, appointments\nand write prescriptions',
                onTap: () => context.go('/auth/login', extra: {'userType': 'doctor'}),
              ),
              const Spacer(),
              Center(
                child: Text('By continuing you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppColors.foreground)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter', height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
