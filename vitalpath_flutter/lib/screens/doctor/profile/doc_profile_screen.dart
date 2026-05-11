import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/doctor.dart';
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
        final docAsync     = ref.watch(doctorProfileProvider(user.uid));
        final patientCount = ref.watch(doctorPatientCountProvider(user.uid)).maybeWhen(data: (c) => c, orElse: () => 0);

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(title: const Text('Doctor Profile'), automaticallyImplyLeading: false),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // ── Profile Header ─────────────────────────────────────────
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                child: Column(children: [
                  AppAvatar(name: user.name, size: 80, imageUrl: user.photoUrl, backgroundColor: AppColors.primary),
                  const SizedBox(height: 14),
                  Text('Dr. ${user.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  docAsync.when(
                    data: (doc) => Column(children: [
                      const SizedBox(height: 4),
                      if (doc?.specialty != null)
                        Text(doc!.specialty!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      if (doc?.hospital != null) ...[
                        const SizedBox(height: 2),
                        Text(doc!.hospital!, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ],
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        _HeaderStat('$patientCount', 'Patients'),
                        Container(width: 1, height: 28, color: AppColors.border),
                        _HeaderStat(doc?.rating.toStringAsFixed(1) ?? '0.0', 'Rating'),
                        Container(width: 1, height: 28, color: AppColors.border),
                        _HeaderStat('${doc?.reviewCount ?? 0}', 'Reviews'),
                      ]),
                    ]),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ]),
              ),

              // Verification banner
              docAsync.whenData((doc) {
                final status = doc?.verificationStatus ?? 'unverified';
                if (status == 'verified') return null;
                return _VerificationBanner(uid: user.uid, isPending: status == 'pending');
              }).value ?? const SizedBox.shrink(),

              const SizedBox(height: 16),

              // ── Professional Information ────────────────────────────────
              docAsync.when(
                data: (doc) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionLabel('Professional Information'),
                  const SizedBox(height: 8),
                  BentoCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _InfoRow('License No.', doc?.licenseNo ?? 'Not set'),
                      _InfoRow('Specialty', doc?.specialty ?? 'Not set'),
                      _InfoRow('Hospital', doc?.hospital ?? 'Not set'),
                      _InfoRow('Phone', doc?.phone ?? user.phone),
                      _InfoRow('Verification', _verificationLabel(doc?.verificationStatus)),
                      if (doc?.availableHours != null && doc!.availableHours!.isNotEmpty)
                        _InfoRow('Available Hours', doc.availableHours!),
                      if (doc?.consultationFee != null && doc!.consultationFee!.isNotEmpty)
                        _InfoRow('Consultation Fee', doc.consultationFee!),
                      _InfoRow('Accepting Patients', doc?.acceptingNewPatients == true ? 'Yes' : 'Not currently'),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ]),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              // ── Professional Settings ──────────────────────────────────
              _SectionLabel('Professional'),
              const SizedBox(height: 8),
              BentoCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  BentoSettingsTile(
                    icon: const Healthcare(width: 18, height: 18),
                    title: 'Edit Profile',
                    onTap: () => _showEditSheet(context, ref, user.uid),
                  ),
                  BentoSettingsTile(
                    icon: const Medal(width: 18, height: 18),
                    title: 'Credentials',
                    onTap: () {},
                  ),
                  BentoSettingsTile(
                    icon: const MapPin(width: 18, height: 18),
                    title: 'Hospital Location',
                    showDivider: false,
                    onTap: () {},
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
                    icon: const Bell(width: 18, height: 18),
                    title: 'Notifications',
                    onTap: () => context.push('/notification-settings'),
                  ),
                  BentoSettingsTile(
                    icon: const Lock(width: 18, height: 18),
                    title: 'Privacy & Security',
                    onTap: () => context.push('/privacy-security'),
                  ),
                  BentoSettingsTile(
                    icon: const QuestionMark(width: 18, height: 18),
                    title: 'Help & Support',
                    showDivider: false,
                    onTap: () => _showHelp(context),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Sign Out ───────────────────────────────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: const LogOut(width: 18, height: 18, color: AppColors.destructive),
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

  void _showEditSheet(BuildContext context, WidgetRef ref, String uid) {
    final doc = ref.read(doctorProfileProvider(uid)).asData?.value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(uid: uid, doc: doc),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text('For assistance, contact us at support@vitalpath.health'),
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
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
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

// ─── Edit Profile Sheet ────────────────────────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final String uid;
  final DoctorProfile? doc;
  const _EditProfileSheet({required this.uid, required this.doc});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _specialtyCtrl;
  late final TextEditingController _hospitalCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _feeCtrl;
  late bool _accepting;

  @override
  void initState() {
    super.initState();
    _specialtyCtrl = TextEditingController(text: widget.doc?.specialty ?? '');
    _hospitalCtrl  = TextEditingController(text: widget.doc?.hospital ?? '');
    _licenseCtrl   = TextEditingController(text: widget.doc?.licenseNo ?? '');
    _hoursCtrl     = TextEditingController(text: widget.doc?.availableHours ?? '');
    _feeCtrl       = TextEditingController(text: widget.doc?.consultationFee ?? '');
    _accepting     = widget.doc?.acceptingNewPatients ?? true;
  }

  @override
  void dispose() {
    _specialtyCtrl.dispose();
    _hospitalCtrl.dispose();
    _licenseCtrl.dispose();
    _hoursCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(controller: _specialtyCtrl,
              decoration: const InputDecoration(labelText: 'Specialty', hintText: 'e.g. Cardiology')),
          const SizedBox(height: 12),
          TextField(controller: _hospitalCtrl,
              decoration: const InputDecoration(labelText: 'Hospital', hintText: 'e.g. City General Hospital')),
          const SizedBox(height: 12),
          TextField(controller: _licenseCtrl,
              decoration: const InputDecoration(labelText: 'License Number')),
          const SizedBox(height: 12),
          TextField(controller: _hoursCtrl,
              decoration: const InputDecoration(labelText: 'Available Hours', hintText: 'e.g. Mon–Fri 9am–5pm')),
          const SizedBox(height: 12),
          TextField(controller: _feeCtrl,
              decoration: const InputDecoration(labelText: 'Consultation Fee', hintText: 'e.g. \$50 / Free')),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('Accepting New Patients',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            Switch(
              value: _accepting,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
              onChanged: (v) => setState(() => _accepting = v),
            ),
          ]),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Save Changes',
            colors: [AppColors.primary, const Color(0xFF5B21B6)],
            onPressed: () async {
              final data = <String, dynamic>{
                'acceptingNewPatients': _accepting,
              };
              if (_specialtyCtrl.text.isNotEmpty) data['specialty'] = _specialtyCtrl.text.trim();
              if (_hospitalCtrl.text.isNotEmpty)  data['hospital']  = _hospitalCtrl.text.trim();
              if (_licenseCtrl.text.isNotEmpty)   data['licenseNo'] = _licenseCtrl.text.trim();
              data['availableHours']  = _hoursCtrl.text.trim().isEmpty ? null : _hoursCtrl.text.trim();
              data['consultationFee'] = _feeCtrl.text.trim().isEmpty  ? null : _feeCtrl.text.trim();
              await ref.read(firestoreServiceProvider).updateDoctorProfile(widget.uid, data);
              ref.invalidate(doctorProfileProvider(widget.uid));
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value, label;
  const _HeaderStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  ]);
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground))),
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
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textTertiary,
      letterSpacing: 0.8,
    ),
  );
}

String _verificationLabel(String? status) => switch (status) {
  'verified' => 'Verified',
  'pending'  => 'Pending review',
  _          => 'Unverified',
};

// ── Verification Banner ───────────────────────────────────────────────────────
class _VerificationBanner extends StatefulWidget {
  final String uid;
  final bool isPending;
  const _VerificationBanner({required this.uid, required this.isPending});
  @override
  State<_VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends State<_VerificationBanner> {
  bool _requesting = false;

  Future<void> _requestVerification() async {
    setState(() => _requesting = true);
    try {
      await FirebaseFirestore.instance
          .collection('verificationRequests')
          .doc(widget.uid)
          .set({
        'uid': widget.uid,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.uid)
          .update({'verificationStatus': 'pending'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification request submitted. We\'ll review within 2–3 business days.')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isPending ? AppColors.warning : AppColors.destructive;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.all(16),
      color: color.withValues(alpha: 0.07),
      child: Row(children: [
        Icon(
          widget.isPending ? Icons.hourglass_top_rounded : Icons.verified_outlined,
          color: color,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.isPending ? 'Verification pending' : 'Profile unverified',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isPending
                  ? 'Your request is under review. We\'ll notify you when it\'s done.'
                  : 'Patients can see this. Request verification to show a trusted badge.',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground),
            ),
          ]),
        ),
        if (!widget.isPending) ...[
          const SizedBox(width: 10),
          _requesting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _requestVerification,
                  style: TextButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Request',
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ),
        ],
      ]),
    );
  }
}
