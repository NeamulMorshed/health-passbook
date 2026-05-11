import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../models/caregiver_connection.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';

class InviteCaregiverScreen extends ConsumerStatefulWidget {
  const InviteCaregiverScreen({super.key});

  @override
  ConsumerState<InviteCaregiverScreen> createState() =>
      _InviteCaregiverScreenState();
}

class _InviteCaregiverScreenState extends ConsumerState<InviteCaregiverScreen> {
  int _step = 0;

  // Step 1
  String? _relationship;

  // Step 2
  CaregiverPermissions _permissions = const CaregiverPermissions();

  // Step 3
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && _relationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a relationship')),
      );
      return;
    }
    setState(() => _step++);
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;
    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;

    final email = _emailCtrl.text.trim();

    // H-IC2: check for an already-pending invite to this email
    final pendingList =
        ref.read(pendingInvitesForEmailProvider(email)).asData?.value ?? [];
    final alreadyPending = pendingList.any((c) => c.status == 'pending');
    if (alreadyPending && mounted) {
      final resend = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Invite already sent'),
          content: Text(
              'An invite was already sent to $email. Send again?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Send Anyway')),
          ],
        ),
      );
      if (resend != true || !mounted) return;
    }

    setState(() => _sending = true);
    final notifier = ref.read(caregiverConnectionNotifierProvider.notifier);
    final id = await notifier.invite(
      patientId: user.uid,
      patientName: user.name,
      caregiverEmail: email,
      relationship: _relationship!,
      permissions: _permissions,
      notifSettings: const CaregiverNotifSettings(),
      personalMessage: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
    );
    // C-IC1: mounted check after async gap
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (id != null) _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // C-IC3: Android back button steps backward through the stepper
    return PopScope(
      canPop: _step == 0 || _sent,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0 && !_sent) setState(() => _step--);
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
          title: Text(_sent ? 'Invite Sent' : 'Invite a Caregiver'),
          leading: _step > 0 && !_sent
              ? IconButton(
                  icon: const NavArrowLeft(width: 18, height: 18),
                  onPressed: () => setState(() => _step--),
                )
              : null,
        ),
        body: _sent ? _ConfirmationView(email: _emailCtrl.text.trim()) : _stepBody(),
      ),
    );
  }

  Widget _stepBody() {
    return Column(
      children: [
        _StepIndicator(current: _step),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: [
              _Step1(
                selected: _relationship,
                onSelect: (r) => setState(() => _relationship = r),
                onNext: _nextStep,
              ),
              _Step2(
                permissions: _permissions,
                onChange: (p) => setState(() => _permissions = p),
                onNext: _nextStep,
              ),
              _Step3(
                formKey: _formKey,
                emailCtrl: _emailCtrl,
                msgCtrl: _msgCtrl,
                sending: _sending,
                onSend: _sendInvite,
              ),
            ][_step],
          ),
        ),
      ],
    );
  }
}

// ── Step progress indicator ───────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.primary
                        : active
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.muted,
                    shape: BoxShape.circle,
                    border: active
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: done
                        ? const Check(width: 14, height: 14, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
                            ),
                          ),
                  ),
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 1: relationship ──────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;

  const _Step1(
      {required this.selected,
      required this.onSelect,
      required this.onNext});

  static const _options = [
    ('spouse', Icons.favorite_rounded, 'Spouse / Partner'),
    ('parent', Icons.elderly_rounded, 'Parent'),
    ('child', Icons.child_care_rounded, 'Child / Adult child'),
    ('sibling', Icons.people_rounded, 'Sibling'),
    ('professional', Icons.medical_services_rounded, 'Professional Caregiver'),
    ('other', Icons.person_rounded, 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who are you inviting?',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Choose the relationship so we can set smart defaults.',
            style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground)),
        const SizedBox(height: 24),
        ..._options.map((o) {
          final (value, icon, label) = o;
          final isSelected = selected == value;
          return GestureDetector(
            onTap: () => onSelect(value),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Icon(icon,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.mutedForeground),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.foreground)),
                ),
                if (isSelected)
                  const CheckCircle(width: 20, height: 20, color: AppColors.primary),
              ]),
            ),
          );
        }),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onNext,
            child: const Text('Next',
                style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

// ── Step 2: permissions ───────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final CaregiverPermissions permissions;
  final ValueChanged<CaregiverPermissions> onChange;
  final VoidCallback onNext;

  const _Step2(
      {required this.permissions,
      required this.onChange,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What can they see?',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('You can change this anytime.',
            style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground)),
        const SizedBox(height: 24),

        _PermRow(
          icon: Icons.medication_rounded,
          label: 'Medicines & dose tracking',
          value: permissions.medicines,
          onChanged: (v) =>
              onChange(permissions.copyWith(medicines: v)),
        ),
        _PermRow(
          icon: Icons.monitor_heart_rounded,
          label: 'Vitals & readings',
          value: permissions.vitals,
          onChanged: (v) =>
              onChange(permissions.copyWith(vitals: v)),
        ),
        _PermRow(
          icon: Icons.calendar_today_rounded,
          label: 'Upcoming appointments',
          value: permissions.appointments,
          onChanged: (v) =>
              onChange(permissions.copyWith(appointments: v)),
        ),
        _PermRow(
          icon: Icons.receipt_long_rounded,
          label: 'Prescriptions',
          value: permissions.prescriptions,
          onChanged: (v) =>
              onChange(permissions.copyWith(prescriptions: v)),
        ),
        _PermRow(
          icon: Icons.restaurant_rounded,
          label: 'Meal logs',
          value: permissions.mealLogs,
          onChanged: (v) =>
              onChange(permissions.copyWith(mealLogs: v)),
        ),
        _PermRow(
          icon: Icons.directions_run_rounded,
          label: 'Activity logs',
          value: permissions.activityLogs,
          onChanged: (v) =>
              onChange(permissions.copyWith(activityLogs: v)),
        ),

        const SizedBox(height: 20),
        BentoCard(
          color: AppColors.muted,
          padding: const EdgeInsets.all(14),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('They will NOT be able to:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              _CantDoRow('Edit your health data'),
              _CantDoRow('Book appointments for you'),
              _CantDoRow("See your doctor's private notes"),
            ],
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onNext,
            child: const Text('Next',
                style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoCard(
        padding: EdgeInsets.zero,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          secondary: Icon(icon, size: 20, color: AppColors.mutedForeground),
          title: Text(label,
              style: const TextStyle(fontSize: 14)),
          activeThumbColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          dense: true,
        ),
      ),
    );
  }
}

class _CantDoRow extends StatelessWidget {
  final String text;
  const _CantDoRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        const Icon(Icons.block_rounded,
            size: 13, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground)),
      ]),
    );
  }
}

// ── Step 3: send invite ───────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController msgCtrl;
  final bool sending;
  final VoidCallback onSend;

  const _Step3({
    required this.formKey,
    required this.emailCtrl,
    required this.msgCtrl,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How do you want to invite them?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Enter the email they use (or will use) to register on VitalPath.',
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground)),
          const SizedBox(height: 24),

          const Text('Email address',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'their@email.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email is required';
              }
              // C-IC2: stricter email regex
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$')
                  .hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),
          const Text('Personal message (optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: msgCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  "I'd like you to be able to check on me through the app...",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: sending ? null : onSend,
              child: sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send Invite',
                      style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirmation ──────────────────────────────────────────────────────────────

class _ConfirmationView extends StatelessWidget {
  final String email;
  const _ConfirmationView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CheckCircle(width: 48, height: 48, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Invite Sent!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            'Once $email accepts, they\'ll appear in your Care Circle.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 6),
          const Text(
            'Invite expires in 7 days.',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Care Circle'),
          ),
        ],
      ),
    );
  }
}
