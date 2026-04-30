import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/doctor_provider.dart';

class DocProfileScreen extends ConsumerWidget {
  const DocProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        final docAsync = ref.watch(doctorProfileProvider(user.uid));
        final patientCount = ref.watch(doctorPatientCountProvider(user.uid)).maybeWhen(data: (c) => c, orElse: () => 0);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Doctor Profile'), automaticallyImplyLeading: false),
          body: ListView(
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.doctorPrimary, Color(0xFF5B21B6)]),
                ),
                child: Column(children: [
                  AppAvatar(name: user.name, size: 80, imageUrl: user.photoUrl, backgroundColor: Colors.white),
                  const SizedBox(height: 14),
                  Text('Dr. ${user.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Inter')),
                  docAsync.when(
                    data: (doc) => Column(children: [
                      const SizedBox(height: 4),
                      if (doc?.specialty != null) Text(doc!.specialty!, style: const TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Inter')),
                      if (doc?.hospital != null) ...[
                        const SizedBox(height: 2),
                        Text(doc!.hospital!, style: const TextStyle(fontSize: 12, color: Colors.white60, fontFamily: 'Inter')),
                      ],
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        _HeaderStat('$patientCount', 'Patients'),
                        Container(width: 1, height: 28, color: Colors.white24),
                        _HeaderStat(doc?.rating.toStringAsFixed(1) ?? '0.0', 'Rating'),
                        Container(width: 1, height: 28, color: Colors.white24),
                        _HeaderStat('${doc?.reviewCount ?? 0}', 'Reviews'),
                      ]),
                    ]),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // Doctor info
              docAsync.when(
                data: (doc) => Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Professional Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    const SizedBox(height: 16),
                    _InfoRow('License No.', doc?.licenseNo ?? 'Not set'),
                    _InfoRow('Specialty', doc?.specialty ?? 'Not set'),
                    _InfoRow('Hospital', doc?.hospital ?? 'Not set'),
                    _InfoRow('Phone', doc?.phone ?? user.phone),
                    _InfoRow('Verified', doc?.isVerified == true ? 'Yes' : 'Pending'),
                  ]),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: 12),

              // Edit profile button
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _showEditSheet(context, ref, user.uid),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.doctorPrimary),
                ),
              ),

              const SizedBox(height: 12),

              // Menu items
              Container(
                color: AppColors.surface,
                child: Column(children: [
                  _MenuItem(icon: Icons.notifications_rounded, label: 'Notifications', color: AppColors.warning, onTap: () => context.push('/notification-settings')),
                  _MenuItem(icon: Icons.security_rounded, label: 'Privacy & Security', color: AppColors.mutedForeground, onTap: () => context.push('/privacy-security')),
                  _MenuItem(icon: Icons.help_outline_rounded, label: 'Help & Support', color: AppColors.primary, onTap: () => _showHelp(context)),
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

  void _showEditSheet(BuildContext context, WidgetRef ref, String uid) {
    final doc = ref.read(doctorProfileProvider(uid)).asData?.value;
    final specialtyCtrl = TextEditingController(text: doc?.specialty ?? '');
    final hospitalCtrl = TextEditingController(text: doc?.hospital ?? '');
    final licenseCtrl = TextEditingController(text: doc?.licenseNo ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            const SizedBox(height: 20),
            TextField(controller: specialtyCtrl, decoration: const InputDecoration(labelText: 'Specialty', hintText: 'e.g. Cardiology')),
            const SizedBox(height: 12),
            TextField(controller: hospitalCtrl, decoration: const InputDecoration(labelText: 'Hospital', hintText: 'e.g. City General Hospital')),
            const SizedBox(height: 12),
            TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'License Number')),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Save Changes',
              colors: [AppColors.doctorPrimary, const Color(0xFF5B21B6)],
              onPressed: () async {
                final data = <String, dynamic>{};
                if (specialtyCtrl.text.isNotEmpty) data['specialty'] = specialtyCtrl.text.trim();
                if (hospitalCtrl.text.isNotEmpty) data['hospital'] = hospitalCtrl.text.trim();
                if (licenseCtrl.text.isNotEmpty) data['licenseNo'] = licenseCtrl.text.trim();
                if (data.isNotEmpty) {
                  await ref.read(firestoreServiceProvider).updateDoctorProfile(uid, data);
                  ref.invalidate(doctorProfileProvider(uid));
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Help & Support', style: TextStyle(fontFamily: 'Inter')),
        content: const Text('For assistance, contact us at support@vitalpath.health', style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final uri = Uri.parse('mailto:support@vitalpath.health?subject=Doctor%20Support%20Request');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out', style: TextStyle(fontFamily: 'Inter')),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/user-select');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value, label;
  const _HeaderStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Inter')),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60, fontFamily: 'Inter')),
  ]);
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter'))),
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
      decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.mutedForeground),
    onTap: onTap,
  );
}
