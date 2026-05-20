import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';

const _uuid = Uuid();

class InviteFamilyMemberScreen extends ConsumerStatefulWidget {
  const InviteFamilyMemberScreen({super.key});

  @override
  ConsumerState<InviteFamilyMemberScreen> createState() =>
      _InviteFamilyMemberScreenState();
}

class _InviteFamilyMemberScreenState
    extends ConsumerState<InviteFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  String? _relationship;
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;
    if (_relationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a relationship')),
      );
      return;
    }
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;

    setState(() => _isSending = true);
    try {
      final inviteId = _uuid.v4();
      await FirebaseFirestore.instance
          .collection('invites')
          .doc(inviteId)
          .set({
        'fromUid': user.uid,
        'fromName': user.name,
        'toEmail': _emailCtrl.text.trim().toLowerCase(),
        'relationship': _relationship,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(
        text:
            'Hey! I\'m using Omra to manage our health together. Search for "Omra health app" to download it, then create an account with this email so we can link up: ${_emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : "your email"}.'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Invite Family Member')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _sent
            ? _SuccessView(
                email: _emailCtrl.text.trim(),
                onCopyMessage: _copyMessage,
              )
            : _FormView(
                formKey: _formKey,
                emailCtrl: _emailCtrl,
                relationship: _relationship,
                onRelationshipChanged: (r) =>
                    setState(() => _relationship = r),
                isSending: _isSending,
                onSend: _sendInvite,
              ),
      ),
    );
  }
}

// ─── Form View ────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final String? relationship;
  final ValueChanged<String> onRelationshipChanged;
  final bool isSending;
  final VoidCallback onSend;

  const _FormView({
    required this.formKey,
    required this.emailCtrl,
    required this.relationship,
    required this.onRelationshipChanged,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card (was gradient Container)
          BentoCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedUserAdd01, color: AppColors.primary, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Invite a linked account',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A linked account means they log in with their own Omra account and you both appear in each other\'s care circle.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // How it works note — custom primary border, keep as Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'When they sign up with this email, the accounts link automatically. No email is sent — share the app link manually.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Email field
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Their email address *',
              hintText: 'e.g. parent@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}');
              if (!emailRegex.hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Relationship chips
          Row(children: [
            const Text(
              'Relationship',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground),
            ),
            const Text(' *',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.destructive)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.relationships.map((r) {
              final selected = relationship == r;
              return GestureDetector(
                onTap: () => onRelationshipChanged(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.muted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : AppColors.foreground),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : HugeIcon(icon: HugeIcons.strokeRoundedLink01, color: Colors.white, size: 18),
              label: Text(
                isSending ? 'Saving…' : 'Save Invite',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Success View ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String email;
  final VoidCallback onCopyMessage;
  const _SuccessView({required this.email, required this.onCopyMessage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: AppColors.success, size: 48),
        ),
        const SizedBox(height: 20),
        const Text(
          'Invite saved!',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground),
        ),
        const SizedBox(height: 8),
        Text(
          'When $email creates an Omra account, they\'ll automatically be linked with your account.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14,
              color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 32),
        BentoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share the app with them',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Copy a message to send them directly.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCopyMessage,
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedCopy, color: AppColors.primary, size: 18),
                  label: const Text('Copy invite message'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Health Circle',
                style: TextStyle(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}
