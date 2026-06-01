import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/disclaimer_provider.dart';

class DisclaimerScreen extends ConsumerWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Medical Disclaimer',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please read before continuing',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _DisclaimerPoint(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        title: 'Not a Medical Device',
                        body:
                            'Omra is a personal health tracker designed to help you log and organise your health information. It is not a licensed medical device, and does not diagnose, treat, cure, or prevent any medical condition.',
                      ),
                      const SizedBox(height: 16),
                      _DisclaimerPoint(
                        icon: HugeIcons.strokeRoundedDoctor01,
                        title: 'Not a Substitute for Professional Advice',
                        body:
                            'Information displayed in Omra — including medicines, vitals, prescriptions, and drug interaction alerts — is for personal reference only. Always consult a qualified healthcare professional before making any medical decision.',
                      ),
                      const SizedBox(height: 16),
                      _DisclaimerPoint(
                        icon: HugeIcons.strokeRoundedAlert02,
                        title: 'Drug Interaction Alerts Are Informational',
                        body:
                            'Any drug interaction or allergy warnings shown in the app are sourced from public databases and may be incomplete. They do not replace a pharmacist\'s or doctor\'s clinical judgement.',
                      ),
                      const SizedBox(height: 16),
                      _DisclaimerPoint(
                        icon: HugeIcons.strokeRoundedLock,
                        title: 'Doctor Accounts Are Self-Declared',
                        body:
                            'Users who register as healthcare professionals are self-declared. Omra does not independently verify medical licences or credentials.',
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          'By tapping "I Understand & Agree" you acknowledge that you have read this disclaimer and agree to use Omra as a personal health-tracking tool, not as medical advice.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(AppConstants.prefDisclaimerAccepted, true);
                    ref.read(disclaimerAcceptedProvider.notifier).state = true;
                    if (context.mounted) context.go('/splash');
                  },
                  child: const Text(
                    'I Understand & Agree',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/privacy-policy'),
                  child: const Text(
                    'Read our Privacy Policy',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerPoint extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String body;
  const _DisclaimerPoint(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: HugeIcon(icon: icon, color: AppColors.textSecondary, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
