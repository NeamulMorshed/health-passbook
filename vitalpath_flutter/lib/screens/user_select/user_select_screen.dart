import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/app_user.dart';
import '../../core/auth/auth_repository.dart';
import '../../providers/auth_provider.dart';

class UserSelectScreen extends ConsumerStatefulWidget {
  const UserSelectScreen({super.key});

  @override
  ConsumerState<UserSelectScreen> createState() => _UserSelectScreenState();
}

class _UserSelectScreenState extends ConsumerState<UserSelectScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _loading,
          message: 'Preparing your account...',
          child: Padding(
            padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 28),
              const Text('Welcome to\nOmra', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground, height: 1.2)),
              const SizedBox(height: 10),
              const Text('How are you using Omra today?', style: TextStyle(fontSize: 15, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              const SizedBox(height: 48),
              _RoleCard(
                icon: Icons.person_rounded,
                color: AppColors.primary,
                title: 'I\'m a Patient',
                subtitle: 'Track medicines, meals, activity\nand connect with your doctor',
                onTap: () => _handleRoleSelected('patient'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.medical_services_rounded,
                color: AppColors.doctorPrimary,
                title: 'I\'m a Doctor',
                subtitle: 'Manage patients, appointments\nand write prescriptions',
                onTap: () => _handleRoleSelected('doctor'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.family_restroom_rounded,
                color: const Color(0xFFF59E0B),
                title: 'I\'m a Caregiver',
                subtitle: 'Manage health for your family\nand connect with their doctors',
                onTap: () => _handleRoleSelected('caregiver'),
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
    ));
  }

  void _handleRoleSelected(String userType) async {
    if (_loading) return;
    
    final authRepo = ref.read(authRepositoryProvider);
    final uid = authRepo.currentUid;
    
    if (uid != null) {
      // User is already signed into Firebase Auth (e.g. they came here from login)
      // but they don't have a Firestore profile yet. Create it now!
      setState(() => _loading = true);
      
      try {
        final result = await authRepo.getUserState(uid);
        if (!mounted) return;
        if (result is AuthSuccess) {
          // Existing profile — navigate to the appropriate destination.
          final user = result.user;
          if (user.userType == UserType.doctor) {
            if (!user.onboardingComplete) {
              context.go('/doc/onboarding/profile');
            } else {
              context.go('/doc/dashboard');
            }
          } else if (user.userType == UserType.caregiver) {
            if (!user.onboardingComplete) {
              context.go('/onboarding/caregiver-setup');
            } else {
              context.go('/home');
            }
          } else if (!user.onboardingComplete) {
            context.go('/onboarding/permissions');
          } else {
            context.go('/auth/faceid');
          }
        } else if (result is AuthNewUser) {
          final parsedType = userType == 'doctor'
              ? UserType.doctor
              : userType == 'caregiver'
                  ? UserType.caregiver
                  : UserType.patient;
          final newUser = AppUser(
            uid: uid,
            name: result.displayName ?? 'New User',
            phone: '',
            userType: parsedType,
            createdAt: DateTime.now(),
          );
          try {
            await authRepo.createProfile(newUser);
          } catch (e) {
            if (mounted) {
              setState(() => _loading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Failed to set up your account. Please check your connection and try again.',
                  ),
                ),
              );
            }
            return;
          }
          if (!mounted) return;
          if (userType == 'doctor') {
            context.go('/doc/onboarding/profile');
          } else if (userType == 'caregiver') {
            context.go('/onboarding/caregiver-setup');
          } else {
            context.go('/onboarding/permissions');
          }
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // User is completely unauthenticated.
      context.go('/auth/login', extra: {'userType': userType});
    }
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
          border: Border.all(color: color.withValues(alpha:0.25), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha:0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(14)),
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
