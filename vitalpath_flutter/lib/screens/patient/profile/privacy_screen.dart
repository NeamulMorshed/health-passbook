import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../screens/legal/privacy_policy_screen.dart';

const _kBiometricPref = 'biometric_enabled';

final _biometricPrefProvider = StateProvider<bool>((ref) => false);

class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});
  @override
  ConsumerState<PrivacySecurityScreen> createState() =>
      _PrivacySecurityScreenState();
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
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently delete your account and all health data. This cannot be undone.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  try {
                    await ref.read(authRepositoryProvider).deleteAccount();
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    context.go('/user-select');
                  } catch (e) {
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    showAppSnack(context,
                        'Could not delete account. Please sign out and sign back in, then try again.');
                  }
                },
                child: const Text('Delete'),
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

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(_biometricPrefProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          const BentoSectionHeader(title: 'Authentication'),
          const SizedBox(height: 8),
          BentoCard(
            padding: EdgeInsets.zero,
            child: BentoSettingsTile(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedFingerPrint,
                  color: AppColors.primary,
                  size: 20),
              title: 'Biometric Login',
              subtitle: _biometricAvailable
                  ? 'Use Face ID or fingerprint to log in'
                  : 'Not available on this device',
              trailing: Switch(
                value: biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                activeThumbColor: AppColors.primary,
              ),
              showDivider: false,
            ),
          ),
          const SizedBox(height: 16),
          const BentoSectionHeader(title: 'Your Data'),
          const SizedBox(height: 8),
          BentoCard(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _InfoRow(
                HugeIcon(
                    icon: HugeIcons.strokeRoundedLock,
                    color: AppColors.mutedForeground,
                    size: 18),
                'Data Encryption',
                'All your health data is encrypted in transit and at rest via Firebase.',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                const Icon(Icons.storage_rounded,
                    size: 18, color: AppColors.mutedForeground),
                'Data Storage',
                'Your data is stored securely in Google Cloud Firestore.',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                HugeIcon(
                    icon: HugeIcons.strokeRoundedShare01,
                    color: AppColors.mutedForeground,
                    size: 18),
                'Data Sharing',
                'Your data is only shared with doctors you connect with.',
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const BentoSectionHeader(title: 'Legal'),
          const SizedBox(height: 8),
          BentoCard(
            padding: EdgeInsets.zero,
            child: BentoSettingsTile(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedFile01,
                  color: AppColors.primary,
                  size: 20),
              title: 'Privacy Policy',
              subtitle: 'How we collect, use and protect your data',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen()),
              ),
              showDivider: false,
            ),
          ),
          const SizedBox(height: 16),
          const BentoSectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          BentoCard(
            padding: EdgeInsets.zero,
            child: BentoSettingsTile(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete01,
                  color: AppColors.destructive,
                  size: 20),
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and data',
              onTap: _showDeleteDialog,
              showDivider: false,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Omra v${AppConstants.appVersion}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  const _InfoRow(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ]),
          ),
        ],
      );
}
