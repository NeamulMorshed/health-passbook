import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final patientAsync = ref.watch(patientProfileProvider(user.uid));

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('My Profile'), automaticallyImplyLeading: false),
          body: ListView(
            children: [
              // Header
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  AppAvatar(name: user.name, size: 72, imageUrl: user.photoUrl),
                  const SizedBox(height: 12),
                  Text(user.name.isNotEmpty ? user.name : 'Patient', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                  const SizedBox(height: 4),
                  Text(user.phone, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
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
                    error: (_, __) => const SizedBox(),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // Health Info
              patientAsync.when(
                data: (patient) {
                  if (patient == null) return const SizedBox();
                  return Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Health Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                      const SizedBox(height: 16),
                      if (patient.bmi != null)
                        _InfoRow('BMI', '${patient.bmi!.toStringAsFixed(1)} (${_bmiLabel(patient.bmi!)})'),
                      if (patient.conditions.isNotEmpty)
                        _InfoRow('Conditions', patient.conditions.join(', ')),
                      if (patient.allergies != null)
                        _InfoRow('Allergies', patient.allergies!),
                      if (patient.emergencyContact != null)
                        _InfoRow('Emergency Contact', patient.emergencyContact!),
                    ]),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: 12),

              // Menu items
              Container(
                color: AppColors.surface,
                child: Column(children: [
                  _MenuItem(icon: Icons.people_rounded, label: 'My Doctors', color: AppColors.doctorPrimary, onTap: () => context.push('/my-doctors')),
                  _MenuItem(icon: Icons.calendar_month_rounded, label: 'Appointments', color: AppColors.primary, onTap: () => context.push('/appointments')),
                  _MenuItem(icon: Icons.receipt_long_rounded, label: 'Prescriptions', color: AppColors.success, onTap: () {}),
                  _MenuItem(icon: Icons.notifications_rounded, label: 'Notifications', color: AppColors.warning, onTap: () {}),
                  _MenuItem(icon: Icons.security_rounded, label: 'Privacy & Security', color: AppColors.mutedForeground, onTap: () {}),
                ]),
              ),

              const SizedBox(height: 12),

              Container(
                color: AppColors.surface,
                child: _MenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: AppColors.destructive,
                  onTap: () => _signOut(context, ref),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out', style: TextStyle(fontFamily: 'Inter')),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/user-select');
            },
            child: const Text('Sign Out'),
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
    Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
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
      SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter'))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Inter'))),
    ]),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.mutedForeground),
    onTap: onTap,
  );
}
