import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';

class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key});
  @override
  ConsumerState<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String? _selectedBlood;
  final List<String> _selectedConditions = [];
  bool _saving = false;

  final _conditions = ['Diabetes', 'Hypertension', 'Asthma', 'Heart Disease', 'Thyroid', 'Kidney Disease', 'Arthritis', 'None'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _ageCtrl.dispose(); _weightCtrl.dispose(); _heightCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Soft weight validation
    final w = double.tryParse(_weightCtrl.text);
    if (w != null && w > 300) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unusual Weight', style: TextStyle(fontFamily: 'Inter')),
          content: Text('${w}kg seems unusual. Are you sure this is correct?', style: const TextStyle(fontFamily: 'Inter')),
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
      await ref.read(firestoreServiceProvider).updatePatientProfile(uid, {
        'name': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text),
        'weight': double.tryParse(_weightCtrl.text),
        'height': double.tryParse(_heightCtrl.text),
        'bloodType': _selectedBlood,
        'conditions': _selectedConditions,
      });
      await ref.read(firestoreServiceProvider).updateUserProfile(uid, {'name': _nameCtrl.text.trim()});
      await ref.read(authRepositoryProvider).markOnboardingComplete(uid);
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Health Profile'), automaticallyImplyLeading: false),
      body: LoadingOverlay(
        isLoading: _saving,
        message: 'Saving profile...',
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha:0.06), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('This info helps personalize your health tracking. You can update it anytime.', style: TextStyle(fontSize: 13, color: AppColors.primary, fontFamily: 'Inter'))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel('Full Name'),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Your full name'),
                validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLabel('Age'),
                  TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(hintText: 'e.g. 32'),
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLabel('Blood Type'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBlood,
                    hint: const Text('Select', style: TextStyle(fontFamily: 'Inter')),
                    decoration: const InputDecoration(),
                    items: AppConstants.bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                    onChanged: (v) => setState(() => _selectedBlood = v),
                  ),
                ])),
              ]),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLabel('Weight (kg)'),
                  TextFormField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'e.g. 65'),
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLabel('Height (cm)'),
                  TextFormField(
                    controller: _heightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'e.g. 170'),
                  ),
                ])),
              ]),
              const SizedBox(height: 20),

              _buildLabel('Medical Conditions'),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _conditions.map((c) {
                  final selected = _selectedConditions.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (c == 'None') {
                        _selectedConditions.clear();
                        if (v) _selectedConditions.add('None');
                      } else {
                        _selectedConditions.remove('None');
                        if (v) { _selectedConditions.add(c); } else { _selectedConditions.remove(c); }
                      }
                    }),
                    selectedColor: AppColors.primary.withValues(alpha:0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(fontFamily: 'Inter', color: selected ? AppColors.primary : AppColors.foreground, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              GradientButton(label: 'Complete Setup', onPressed: _save, isLoading: _saving),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground, fontFamily: 'Inter')),
  );
}
