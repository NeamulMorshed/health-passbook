import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _bloodTypeCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  File? _pickedImage;
  bool _saving = false;
  bool _loaded = false;

  static const _bloodTypes = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];
  String? _selectedBloodType;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _bloodTypeCtrl.dispose();
    _conditionsCtrl.dispose();
    _allergiesCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loaded) return;
    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null) return;
    _nameCtrl.text = user.name;
    _phoneCtrl.text = user.phone;
    final patient = ref.read(patientProfileProvider(user.uid)).asData?.value;
    if (patient != null) {
      _ageCtrl.text = patient.age?.toString() ?? '';
      _weightCtrl.text = patient.weight?.toStringAsFixed(0) ?? '';
      _heightCtrl.text = patient.height?.toStringAsFixed(0) ?? '';
      _selectedBloodType = _bloodTypes.contains(patient.bloodType) ? patient.bloodType : null;
      _conditionsCtrl.text = patient.conditions.join(', ');
      _allergiesCtrl.text = patient.allergies ?? '';
      _emergencyCtrl.text = patient.emergencyContact ?? '';
    }
    _loaded = true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_pickedImage == null) return null;
    final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');
    await ref.putFile(_pickedImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user == null) return;

      final photoUrl = await _uploadPhoto(user.uid);

      await ref.read(firestoreServiceProvider).updateUserProfile(user.uid, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      final conditions = _conditionsCtrl.text.trim().isEmpty
          ? <String>[]
          : _conditionsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      await ref.read(firestoreServiceProvider).updatePatientProfile(user.uid, {
        'name': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text),
        'weight': double.tryParse(_weightCtrl.text),
        'height': double.tryParse(_heightCtrl.text),
        'bloodType': _selectedBloodType,
        'conditions': conditions,
        'allergies': _allergiesCtrl.text.trim().isEmpty ? null : _allergiesCtrl.text.trim(),
        'emergencyContact': _emergencyCtrl.text.trim().isEmpty ? null : _emergencyCtrl.text.trim(),
      });

      ref.invalidate(currentUserProvider);
      ref.invalidate(patientProfileProvider(user.uid));

      if (mounted) {
        showAppSnack(context, 'Profile updated successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final user = ref.watch(currentUserProvider).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        image: _pickedImage != null
                            ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                            : (user?.photoUrl != null
                                ? DecorationImage(image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover)
                                : null),
                      ),
                      child: (_pickedImage == null && user?.photoUrl == null)
                          ? Center(
                              child: Text(
                                (user?.name ?? 'P').split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join(),
                                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Inter'),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _SectionLabel('Personal Information'),
            const SizedBox(height: 12),
            _Field(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
            const SizedBox(height: 12),
            _Field(controller: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 24),

            _SectionLabel('Health Information'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(controller: _ageCtrl, label: 'Age', icon: Icons.cake_outlined, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBloodType,
                  decoration: InputDecoration(
                    labelText: 'Blood Type',
                    prefixIcon: const Icon(Icons.bloodtype_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    filled: true, fillColor: AppColors.muted,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: _bloodTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                  onChanged: (v) => setState(() => _selectedBloodType = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(controller: _weightCtrl, label: 'Weight (kg)', icon: Icons.monitor_weight_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 12),
              Expanded(child: _Field(controller: _heightCtrl, label: 'Height (cm)', icon: Icons.height_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 12),
            _Field(controller: _conditionsCtrl, label: 'Conditions (comma-separated)', icon: Icons.medical_information_outlined, maxLines: 2),
            const SizedBox(height: 12),
            _Field(controller: _allergiesCtrl, label: 'Allergies', icon: Icons.warning_amber_rounded),
            const SizedBox(height: 24),

            _SectionLabel('Emergency'),
            const SizedBox(height: 12),
            _Field(controller: _emergencyCtrl, label: 'Emergency Contact', icon: Icons.contact_phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontFamily: 'Inter', letterSpacing: 0.5));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          filled: true, fillColor: AppColors.muted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
