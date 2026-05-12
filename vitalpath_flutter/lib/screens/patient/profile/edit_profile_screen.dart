import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/patient.dart';
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
  DateTime? _dob;
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _ecRelCtrl = TextEditingController();

  File? _pickedImage;
  bool _saving = false;
  bool _loaded = false;
  bool _isDirty = false;

  static const _bloodTypes = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];
  String? _selectedBloodType;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null) setState(() { _dob = picked; _isDirty = true; });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _conditionsCtrl.dispose();
    _allergiesCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _ecRelCtrl.dispose();
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
      _dob = patient.dateOfBirth;
      _weightCtrl.text = patient.weight?.toStringAsFixed(0) ?? '';
      _heightCtrl.text = patient.height?.toStringAsFixed(0) ?? '';
      _selectedBloodType = _bloodTypes.contains(patient.bloodType) ? patient.bloodType : null;
      _conditionsCtrl.text = patient.conditions.join(', ');
      _allergiesCtrl.text = patient.allergies ?? '';
      _ecNameCtrl.text = patient.emergencyContact?.name ?? '';
      _ecPhoneCtrl.text = patient.emergencyContact?.phone ?? '';
      _ecRelCtrl.text = patient.emergencyContact?.relationship ?? '';
    }
    _loaded = true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked != null) setState(() { _pickedImage = File(picked.path); _isDirty = true; });
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
        'dateOfBirth': _dob != null ? Timestamp.fromDate(_dob!) : null,
        'weight': double.tryParse(_weightCtrl.text),
        'height': double.tryParse(_heightCtrl.text),
        'bloodType': _selectedBloodType,
        'conditions': conditions,
        'allergies': _allergiesCtrl.text.trim().isEmpty ? null : _allergiesCtrl.text.trim(),
        'emergencyContact': _ecNameCtrl.text.trim().isEmpty && _ecPhoneCtrl.text.trim().isEmpty
            ? null
            : EmergencyContact(
                name: _ecNameCtrl.text.trim(),
                phone: _ecPhoneCtrl.text.trim(),
                relationship: _ecRelCtrl.text.trim(),
              ).toMap(),
      });

      ref.invalidate(currentUserProvider);
      ref.invalidate(patientProfileProvider(user.uid));

      if (mounted) {
        setState(() => _isDirty = false);
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

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('You have unsaved changes. Leave without saving?'),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep editing'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
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
                                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Camera(width: 14, height: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const BentoSectionHeader(title: 'Personal Information'),
            const SizedBox(height: 12),
            _Field(
              controller: _nameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              onChanged: (_) => setState(() => _isDirty = true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _phoneCtrl,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() => _isDirty = true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(r'^\+?[\d\s\-\(\)]{7,15}$').hasMatch(v.trim())) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 24),

            const BentoSectionHeader(title: 'Health Information'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _DobPicker(dob: _dob, onTap: _pickDob)),
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
                  items: _bloodTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() { _selectedBloodType = v; _isDirty = true; }),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(
                controller: _weightCtrl,
                label: 'Weight (kg)',
                icon: Icons.monitor_weight_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _isDirty = true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final w = double.tryParse(v.trim());
                  if (w == null || w <= 0 || w > 500) return 'Enter a valid weight (1–500 kg)';
                  return null;
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _Field(
                controller: _heightCtrl,
                label: 'Height (cm)',
                icon: Icons.height_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _isDirty = true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final h = double.tryParse(v.trim());
                  if (h == null || h <= 0 || h > 300) return 'Enter a valid height (1–300 cm)';
                  return null;
                },
              )),
            ]),
            const SizedBox(height: 12),
            _Field(controller: _conditionsCtrl, label: 'Conditions (comma-separated)', icon: Icons.medical_information_outlined, maxLines: 2, onChanged: (_) => setState(() => _isDirty = true)),
            const SizedBox(height: 12),
            _Field(controller: _allergiesCtrl, label: 'Allergies', icon: Icons.warning_amber_rounded, onChanged: (_) => setState(() => _isDirty = true)),
            const SizedBox(height: 24),

            const BentoSectionHeader(title: 'Emergency Contact'),
            const SizedBox(height: 12),
            _Field(controller: _ecNameCtrl, label: 'Contact Name', icon: Icons.person_outline_rounded, onChanged: (_) => setState(() => _isDirty = true)),
            const SizedBox(height: 12),
            _Field(
              controller: _ecPhoneCtrl,
              label: 'Contact Phone',
              icon: Icons.contact_phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                final name = _ecNameCtrl.text.trim();
                final phone = v?.trim() ?? '';
                if (name.isNotEmpty && phone.isEmpty) {
                  return 'Phone number required when name is set';
                }
                if (phone.isNotEmpty) {
                  final cleaned = phone.replaceAll(RegExp(r'[\s\-().+]'), '');
                  if (cleaned.length < 7 || !RegExp(r'^\d+$').hasMatch(cleaned)) {
                    return 'Enter a valid phone number';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Field(controller: _ecRelCtrl, label: 'Relationship (e.g. Spouse)', icon: Icons.people_outline_rounded, onChanged: (_) => setState(() => _isDirty = true)),
          ],
        ),
      ),
    ),
    );
  }
}

class _DobPicker extends StatelessWidget {
  final DateTime? dob;
  final VoidCallback onTap;
  const _DobPicker({required this.dob, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = dob != null ? DateFormat('d MMM yyyy').format(dob!) : 'Date of Birth';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.cake_outlined, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          filled: true, fillColor: AppColors.muted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: dob != null ? AppColors.foreground : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
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
