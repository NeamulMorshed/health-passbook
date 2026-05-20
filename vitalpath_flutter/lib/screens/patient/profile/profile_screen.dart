import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/gamification_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(body: Center(child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: 'Pull to refresh or try again.',
      ))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        final patientAsync = ref.watch(patientProfileProvider(user.uid));
        final gamAsync     = ref.watch(gamificationProvider(user.uid));

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            title: const Text('My Profile'),
            automaticallyImplyLeading: false,
            actions: const [NotifBell()],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // ── Profile Header ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                child: Column(children: [
                  AppAvatar(name: user.name, size: 72, imageUrl: user.photoUrl),
                  const SizedBox(height: 12),
                  Text(
                    user.name.isNotEmpty ? user.name : 'Patient',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.phone,
                    style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 8),
                  gamAsync.when(
                    data: (g) => GestureDetector(
                      onTap: () => context.push('/gamification'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedMedal01, color: AppColors.primary, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'Lv ${g.level} • ${g.hp} HP',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ]),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  patientAsync.when(
                    data: (patient) {
                      if (patient == null) return const SizedBox();
                      return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        _ProfileStat('${patient.age ?? '--'}', 'Age'),
                        _Divider(),
                        _ProfileStat('${patient.weight?.toStringAsFixed(0) ?? '--'} kg', 'Weight'),
                        _Divider(),
                        _ProfileStat('${patient.height?.toStringAsFixed(0) ?? '--'} cm', 'Height'),
                        _Divider(),
                        _ProfileStat(patient.bloodType ?? '--', 'Blood Type'),
                      ]);
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(children: [
                        const Text('Failed to load health info', style: TextStyle(color: AppColors.mutedForeground)),
                        TextButton(onPressed: () => ref.invalidate(patientProfileProvider(user.uid)), child: const Text('Retry')),
                      ]),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Streak & Points ────────────────────────────────────────
              gamAsync.when(
                data: (g) => BentoCard(
                  padding: EdgeInsets.zero,
                  child: IntrinsicHeight(
                    child: Row(children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${g.medStreak}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                              const Text('Streak Days', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 0.5, color: AppColors.border),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${g.hp}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                              const Text('Points', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // ── Health Information ─────────────────────────────────────
              patientAsync.when(
                data: (patient) {
                  if (patient == null) return const SizedBox();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _SectionLabel('Health Information'),
                    const SizedBox(height: 8),
                    BentoCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (patient.bmi != null)
                          _InfoRow('BMI', '${patient.bmi!.toStringAsFixed(1)} (${_bmiLabel(patient.bmi!)})'),
                        if (patient.conditions.isNotEmpty)
                          _InfoRow('Conditions', patient.conditions.join(', ')),
                        if (patient.allergies != null)
                          _InfoRow('Allergies', patient.allergies!),
                        if (patient.emergencyContact != null) ...[
                          _InfoRow('Emergency Contact',
                              patient.emergencyContact!.name.isNotEmpty
                                  ? patient.emergencyContact!.name
                                  : patient.emergencyContact!.phone),
                          if (patient.emergencyContact!.relationship.isNotEmpty)
                            _InfoRow('EC Relationship', patient.emergencyContact!.relationship),
                          if (patient.emergencyContact!.name.isNotEmpty &&
                              patient.emergencyContact!.phone.isNotEmpty)
                            _InfoRow('Emergency Phone', patient.emergencyContact!.phone),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ]);
                },
                loading: () => const SizedBox(),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    const Text('Failed to load health info', style: TextStyle(color: AppColors.mutedForeground)),
                    TextButton(onPressed: () => ref.invalidate(patientProfileProvider(user.uid)), child: const Text('Retry')),
                  ]),
                ),
              ),

              // ── Family & Care ──────────────────────────────────────────
              _SectionLabel('Family & Care'),
              const SizedBox(height: 8),
              BentoCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedGroup, color: AppColors.textPrimary, size: 18),
                    title: 'Care Circle',
                    subtitle: 'Manage caregivers & family',
                    showDivider: false,
                    onTap: () => context.push('/care-circle'),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Health ─────────────────────────────────────────────────
              _SectionLabel('Health'),
              const SizedBox(height: 8),
              BentoCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  // TODO: Build dedicated health profile view/edit screen
                  // BentoSettingsTile(
                  //   icon: const HealthShield(width: 18, height: 18),
                  //   title: 'Health Profile',
                  //   onTap: () => context.push('/onboarding/health-profile'),
                  // ),
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: AppColors.textPrimary, size: 18),
                    title: 'Appointments',
                    onTap: () => context.go('/appointments'),
                  ),
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedNote, color: AppColors.textPrimary, size: 18),
                    title: 'Prescriptions',
                    onTap: () => context.push('/prescriptions'),
                  ),
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedAward01, color: AppColors.textPrimary, size: 18),
                    title: 'Achievements',
                    onTap: () => context.push('/gamification'),
                  ),
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedChartIncrease, color: AppColors.textPrimary, size: 18),
                    title: 'Insights',
                    showDivider: false,
                    onTap: () => context.push('/insights'),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Settings ───────────────────────────────────────────────
              _SectionLabel('Settings'),
              const SizedBox(height: 8),
              BentoCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit01, color: AppColors.textPrimary, size: 18),
                    title: 'Edit Profile',
                    onTap: () => context.push('/edit-profile'),
                  ),
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedBellDot, color: AppColors.textPrimary, size: 18),
                    title: 'Notifications',
                    onTap: () => context.push('/notification-settings'),
                  ),
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedLock, color: AppColors.textPrimary, size: 18),
                    title: 'Privacy',
                    showDivider: false,
                    onTap: () => context.push('/privacy-security'),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Account ────────────────────────────────────────────────
              _SectionLabel('Account'),
              const SizedBox(height: 8),
              BentoCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  BentoSettingsTile(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedQuestion, color: AppColors.textPrimary, size: 18),
                    title: 'Help & Support',
                    showDivider: false,
                    onTap: () => launchUrl(Uri.parse('mailto:support@omra.health')),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Sign Out ───────────────────────────────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedLogout01, color: AppColors.destructive, size: 18),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.destructive, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                  } catch (_) {}
                  if (context.mounted) context.go('/user-select');
                },
                child: const Text('Sign Out'),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value, label;
  const _ProfileStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground)),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32, color: AppColors.border);
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textTertiary,
      letterSpacing: 0.8,
    ),
  );
}
