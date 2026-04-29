import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';

const _kBiometricPref = 'biometric_enabled';

final _biometricPrefProvider = StateProvider<bool>((ref) => false);

class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});
  @override
  ConsumerState<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends ConsumerState<PrivacySecurityScreen> {
  final _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kBiometricPref) ?? false;
    ref.read(_biometricPrefProvider.notifier).state = enabled;

    final canCheck = await _localAuth.canCheckBiometrics;
    final available = await _localAuth.isDeviceSupported();
    if (mounted) setState(() => _biometricAvailable = canCheck || available);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to enable biometrics',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (!authenticated) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricPref, value);
    ref.read(_biometricPrefProvider.notifier).state = value;
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontFamily: 'Inter')),
        content: const Text('This will permanently delete your account and all health data. This cannot be undone.', style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(authRepositoryProvider).deleteAccount();
                if (context.mounted) context.go('/user-select');
              } catch (e) {
                if (context.mounted) {
                  showAppSnack(context, 'Could not delete account. Please sign out and sign back in, then try again.');
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(_biometricPrefProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        children: [
          // Biometric section
          const SizedBox(height: 12),
          _SectionHeader('Authentication'),
          Container(
            color: AppColors.surface,
            child: Column(children: [
              SwitchListTile(
                value: biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 20),
                ),
                title: const Text('Biometric Login', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                subtitle: Text(
                  _biometricAvailable ? 'Use Face ID or fingerprint to log in' : 'Not available on this device',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter'),
                ),
                activeThumbColor: AppColors.primary,
              ),
            ]),
          ),

          const SizedBox(height: 12),
          _SectionHeader('Your Data'),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _InfoRow(Icons.lock_outline_rounded, 'Data Encryption', 'All your health data is encrypted in transit and at rest via Firebase.'),
              const SizedBox(height: 12),
              _InfoRow(Icons.storage_rounded, 'Data Storage', 'Your data is stored securely in Google Cloud Firestore.'),
              const SizedBox(height: 12),
              _InfoRow(Icons.share_outlined, 'Data Sharing', 'Your data is only shared with doctors you connect with.'),
            ]),
          ),

          const SizedBox(height: 12),
          _SectionHeader('Account'),
          Container(
            color: AppColors.surface,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.destructive.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.destructive, size: 20),
              ),
              title: const Text('Delete Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.destructive, fontFamily: 'Inter')),
              subtitle: const Text('Permanently delete your account and data', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.mutedForeground),
              onTap: _showDeleteDialog,
            ),
          ),

          const SizedBox(height: 12),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('VitalPath v1.2.1', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontFamily: 'Inter', letterSpacing: 0.5)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoRow(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.mutedForeground),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        ])),
      ]);
}
