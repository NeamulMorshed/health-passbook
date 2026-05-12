import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';

class DocProfileSetupScreen extends ConsumerStatefulWidget {
  const DocProfileSetupScreen({super.key});
  @override
  ConsumerState<DocProfileSetupScreen> createState() =>
      _DocProfileSetupScreenState();
}

class _DocProfileSetupScreenState
    extends ConsumerState<DocProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _specialty;
  bool _accepting = true;

  static const _specialties = [
    'General Physician',
    'Cardiologist',
    'Dermatologist',
    'Endocrinologist',
    'ENT Specialist',
    'Gastroenterologist',
    'Gynecologist',
    'Nephrologist',
    'Neurologist',
    'Oncologist',
    'Ophthalmologist',
    'Orthopedic Surgeon',
    'Pediatrician',
    'Psychiatrist',
    'Pulmonologist',
    'Rheumatologist',
    'Urologist',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await ref.read(currentUserProvider.future);
      if (mounted && user != null && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = user.name == 'New User' ? '' : user.name;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _hospitalCtrl.dispose();
    _hoursCtrl.dispose();
    _feeCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(authRepositoryProvider).currentUid;
      if (uid == null) return;

      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();

      await ref.read(firestoreServiceProvider).updateDoctorProfile(uid, {
        'name': name,
        'phone': phone,
        'specialty': _specialty,
        'licenseNo': _licenseCtrl.text.trim(),
        'hospital': _hospitalCtrl.text.trim(),
        'acceptingNewPatients': _accepting,
        'availableHours': _hoursCtrl.text.trim().isEmpty ? null : _hoursCtrl.text.trim(),
        'consultationFee': _feeCtrl.text.trim().isEmpty ? null : _feeCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      });

      await ref.read(firestoreServiceProvider).updateUserProfile(uid, {
        'name': name,
        'phone': phone,
      });

      await ref.read(authRepositoryProvider).markOnboardingComplete(uid);

      if (mounted) context.go('/doc/dashboard');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: LoadingOverlay(
        isLoading: _saving,
        message: 'Setting up your profile…',
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),

                // ── Header ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF5B21B6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: HugeIcon(icon: HugeIcons.strokeRoundedHealth, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set Up Your Profile',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Complete your details to get started.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Fields ─────────────────────────────────────────────
                _label('Full Name'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Dr. Sarah Ahmed'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                _label('Mobile Number'),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\d\+\-\s\(\)]'))
                  ],
                  decoration:
                      const InputDecoration(hintText: '+1 (555) 000-0000'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? 'Mobile number is required'
                          : null,
                ),
                const SizedBox(height: 16),

                _label('Specialty'),
                DropdownButtonFormField<String>(
                  initialValue: _specialty,
                  hint: const Text('Select your specialty'),
                  decoration: const InputDecoration(),
                  isExpanded: true,
                  items: _specialties
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s)))
                      .toList(),
                  validator: (v) =>
                      v == null ? 'Please select your specialty' : null,
                  onChanged: (v) => setState(() => _specialty = v),
                ),
                const SizedBox(height: 16),

                _label('Medical License Number'),
                TextFormField(
                  controller: _licenseCtrl,
                  decoration:
                      const InputDecoration(hintText: 'e.g. MD-123456'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'License number is required'
                      : null,
                ),
                const SizedBox(height: 16),

                _label('Hospital / Clinic'),
                TextFormField(
                  controller: _hospitalCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'e.g. City General Hospital'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Hospital or clinic name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                _label('Available Hours (optional)'),
                TextFormField(
                  controller: _hoursCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Mon–Fri 9am–5pm'),
                ),
                const SizedBox(height: 16),

                _label('Consultation Fee (optional)'),
                TextFormField(
                  controller: _feeCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. \$50 / Free'),
                ),
                const SizedBox(height: 16),

                _label('City (optional)'),
                TextFormField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Dhaka'),
                ),
                const SizedBox(height: 16),

                BentoCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    const Expanded(child: Text('Accepting New Patients',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    Switch(
                      value: _accepting,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                      onChanged: (v) => setState(() => _accepting = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 36),

                GradientButton(
                  label: 'Complete Setup',
                  colors: const [AppColors.primary, Color(0xFF5B21B6)],
                  onPressed: _save,
                  isLoading: _saving,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground),
        ),
      );
}
