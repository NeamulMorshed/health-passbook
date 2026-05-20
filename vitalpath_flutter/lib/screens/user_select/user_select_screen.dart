import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
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
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
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
                child: SvgPicture.asset('assets/icons/icon.svg', width: 32, height: 32),
              ),
              const SizedBox(height: 28),
              const Text('Welcome to\nOmra', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.foreground, height: 1.2)),
              const SizedBox(height: 10),
              const Text('How are you using Omra today?', style: TextStyle(fontSize: 15, color: AppColors.mutedForeground)),
              const SizedBox(height: 48),
              _RoleCard(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedUser, color: AppColors.primary, size: 28),
                color: AppColors.primary,
                title: 'I\'m a Patient',
                subtitle: 'Track medicines, meals, activity\nand connect with your doctor',
                onTap: () => _handleRoleSelected('patient'),
                isSelected: _selectedRole == 'patient',
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedHealth, color: AppColors.primary, size: 28),
                color: AppColors.primary,
                title: 'I\'m a Doctor',
                subtitle: 'Manage patients, appointments\nand write prescriptions',
                onTap: () => _handleRoleSelected('doctor'),
                isSelected: _selectedRole == 'doctor',
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedGroup, color: Color(0xFFF59E0B), size: 28),
                color: const Color(0xFFF59E0B),
                title: 'I\'m a Family Member',
                subtitle: 'Monitor health for someone you care for\nand connect with their doctors',
                onTap: () => _handleRoleSelected('caregiver'),
                isSelected: _selectedRole == 'caregiver',
              ),
              const Spacer(),
              const Center(
                child: Text('By continuing you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
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
    setState(() => _selectedRole = userType);

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
              context.go('/caregiver/home');
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
  final Widget icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSelected;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : color.withValues(alpha: 0.25),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, height: 1.4)),
                    ],
                  ),
                ),
                HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: color, size: 20),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: AppColors.primary, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}
