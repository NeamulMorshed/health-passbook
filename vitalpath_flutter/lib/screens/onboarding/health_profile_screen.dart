import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../models/patient.dart';

class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key});
  @override
  ConsumerState<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _saving = false;

  // Step 1 fields
  final _nameCtrl = TextEditingController();
  DateTime? _dob;

  // Step 2 fields
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String? _selectedBlood;

  // Step 3 fields
  final List<String> _selectedConditions = [];
  final _allergiesCtrl   = TextEditingController();
  final _ecNameCtrl      = TextEditingController();
  final _ecPhoneCtrl     = TextEditingController();

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _allergiesCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 0 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name to continue.')),
      );
      return;
    }
    if (_page < 2) {
      setState(() => _page++);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _save();
    }
  }

  void _back() {
    if (_page > 0) {
      setState(() => _page--);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _skipStep() {
    if (_page < 2) {
      setState(() => _page++);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    // Soft weight validation
    final w = double.tryParse(_weightCtrl.text);
    if (w != null && w > 300) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unusual Weight', style: TextStyle(fontFamily: 'Inter')),
          content: Text('${w}kg seems unusual. Are you sure this is correct?',
              style: const TextStyle(fontFamily: 'Inter')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Edit')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authRepositoryProvider).currentUid;
      if (uid == null) return;

      // Fix M — Build the profile map without including dateOfBirth when null
      // (omitting the key entirely avoids writing null to Firestore).
      final profileData = <String, dynamic>{
        'name':             _nameCtrl.text.trim(),
        'weight':           double.tryParse(_weightCtrl.text),
        'height':           double.tryParse(_heightCtrl.text),
        'bloodType':        _selectedBlood,
        'conditions':       _selectedConditions,
        'allergies':        _allergiesCtrl.text.trim().isEmpty
            ? null
            : _allergiesCtrl.text.trim(),
        'emergencyContact': _ecNameCtrl.text.trim().isEmpty &&
                _ecPhoneCtrl.text.trim().isEmpty
            ? null
            : EmergencyContact(
                name: _ecNameCtrl.text.trim(),
                phone: _ecPhoneCtrl.text.trim(),
              ).toMap(),
      };
      if (_dob != null) {
        profileData['dateOfBirth'] = Timestamp.fromDate(_dob!);
      }

      await ref.read(firestoreServiceProvider).updatePatientProfile(uid, profileData);
      await ref.read(firestoreServiceProvider).updateUserProfile(uid, {
        'name': _nameCtrl.text.trim(),
      });
      await ref.read(authRepositoryProvider).markOnboardingComplete(uid);
      if (mounted) context.go('/home');
    } catch (e) {
      // Fix H — surface Firestore errors to the user.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save profile. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['Basic Info', 'Body Metrics', 'Medical Details'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Health Profile'),
        automaticallyImplyLeading: false,
        leading: _page > 0
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back)
            : null,
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        message: 'Saving profile...',
        child: Column(children: [
          // ── Progress bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: List.generate(3, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= _page ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ))),
              const SizedBox(height: 6),
              Text('Step ${_page + 1} of 3 — ${steps[_page]}',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ]),
          ),

          // ── Pages ─────────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(nameCtrl: _nameCtrl, dob: _dob, onPickDob: _pickDob),
                _Step2(
                  weightCtrl: _weightCtrl,
                  heightCtrl: _heightCtrl,
                  selectedBlood: _selectedBlood,
                  onBloodChanged: (v) => setState(() => _selectedBlood = v),
                ),
                _Step3(
                  selectedConditions: _selectedConditions,
                  allergiesCtrl: _allergiesCtrl,
                  ecNameCtrl: _ecNameCtrl,
                  ecPhoneCtrl: _ecPhoneCtrl,
                  onConditionChanged: (c, selected) => setState(() {
                    if (c == 'None') {
                      _selectedConditions.clear();
                      if (selected) _selectedConditions.add('None');
                    } else {
                      _selectedConditions.remove('None');
                      if (selected) {
                        _selectedConditions.add(c);
                      } else {
                        _selectedConditions.remove(c);
                      }
                    }
                  }),
                ),
              ],
            ),
          ),

          // ── Bottom buttons ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(children: [
              GradientButton(
                label: _page < 2 ? 'Next' : 'Complete Setup',
                onPressed: _next,
                isLoading: _saving,
              ),
              if (_page > 0) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _skipStep,
                  child: Text(
                    _page < 2 ? 'Skip this step' : 'Skip',
                    style: const TextStyle(color: AppColors.mutedForeground, fontFamily: 'Inter'),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Step 1: Basic Info ─────────────────────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final DateTime? dob;
  final VoidCallback onPickDob;
  const _Step1({required this.nameCtrl, required this.dob, required this.onPickDob});

  @override
  Widget build(BuildContext context) {
    final dobLabel = dob != null ? DateFormat('d MMM yyyy').format(dob!) : 'Tap to select';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _infoBox('Tell us who you are so we can personalise your experience.'),
        const SizedBox(height: 24),
        _label('Full Name'),
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your full name'),
        ),
        const SizedBox(height: 16),
        _label('Date of Birth (optional)'),
        InkWell(
          onTap: onPickDob,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.cake_outlined, size: 20, color: AppColors.mutedForeground),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Tap to select',
            ),
            child: Text(
              dobLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                color: dob != null ? AppColors.foreground : AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 2: Body Metrics ───────────────────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final TextEditingController weightCtrl, heightCtrl;
  final String? selectedBlood;
  final ValueChanged<String?> onBloodChanged;
  const _Step2({
    required this.weightCtrl,
    required this.heightCtrl,
    required this.selectedBlood,
    required this.onBloodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _infoBox('Optional — helps calculate BMI and personalise health insights.'),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Weight (kg)'),
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g. 65'),
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Height (cm)'),
            TextField(
              controller: heightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g. 170'),
            ),
          ])),
        ]),
        const SizedBox(height: 16),
        _label('Blood Type'),
        DropdownButtonFormField<String>(
          initialValue: selectedBlood,
          hint: const Text('Select', style: TextStyle(fontFamily: 'Inter')),
          decoration: const InputDecoration(),
          items: AppConstants.bloodTypes
              .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontFamily: 'Inter'))))
              .toList(),
          onChanged: onBloodChanged,
        ),
      ],
    );
  }
}

// ── Step 3: Medical Details ────────────────────────────────────────────────────
class _Step3 extends StatelessWidget {
  final List<String> selectedConditions;
  final TextEditingController allergiesCtrl;
  final TextEditingController ecNameCtrl;
  final TextEditingController ecPhoneCtrl;
  final void Function(String condition, bool selected) onConditionChanged;

  static const _conditions = [
    'Diabetes', 'Hypertension', 'Asthma', 'Heart Disease',
    'Thyroid', 'Kidney Disease', 'Arthritis', 'None',
  ];

  const _Step3({
    required this.selectedConditions,
    required this.allergiesCtrl,
    required this.ecNameCtrl,
    required this.ecPhoneCtrl,
    required this.onConditionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _infoBox('Optional — helps your doctor understand your background at a glance.'),
        const SizedBox(height: 24),
        _label('Medical Conditions'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _conditions.map((c) {
            final selected = selectedConditions.contains(c);
            return FilterChip(
              label: Text(c),
              selected: selected,
              onSelected: (v) => onConditionChanged(c, v),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                color: selected ? AppColors.primary : AppColors.foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _label('Allergies (optional)'),
        TextField(
          controller: allergiesCtrl,
          decoration: const InputDecoration(hintText: 'e.g. Penicillin, Peanuts'),
        ),
        const SizedBox(height: 16),
        _label('Emergency Contact (optional)'),
        TextField(
          controller: ecNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Contact name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: ecPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'Phone number'),
        ),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground, fontFamily: 'Inter')),
    );

Widget _infoBox(String text) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.primary, fontFamily: 'Inter'))),
      ]),
    );
