import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/family_member.dart';
import '../../../providers/patient_provider.dart';

class AddFamilyMemberScreen extends ConsumerStatefulWidget {
  final String uid;
  final FamilyMember? existing;

  const AddFamilyMemberScreen({super.key, required this.uid, this.existing});

  @override
  ConsumerState<AddFamilyMemberScreen> createState() =>
      _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState
    extends ConsumerState<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late String _relationship;
  String? _photoUrl;
  File? _photoFile;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _ageCtrl = TextEditingController(text: m?.age?.toString() ?? '');
    _relationship = m?.relationship ?? AppConstants.relationships.first;
    _photoUrl = m?.photoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (picked == null) return;
    setState(() => _photoFile = File(picked.path));
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_photoFile == null) return _photoUrl;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('${AppConstants.storageProfilePhotos}/family/$uid/$ts.jpg');
    await ref.putFile(_photoFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final uploadedUrl = await _uploadPhoto(widget.uid);
      final notifier = ref.read(familyMemberNotifierProvider.notifier);
      if (_isEdit) {
        final updated = FamilyMember(
          id: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          relationship: _relationship,
          age: int.tryParse(_ageCtrl.text),
          photoUrl: uploadedUrl,
          createdAt: widget.existing!.createdAt,
        );
        await notifier.update(widget.uid, updated);
      } else {
        await notifier.add(
          widget.uid,
          name: _nameCtrl.text.trim(),
          relationship: _relationship,
          age: int.tryParse(_ageCtrl.text),
          photoUrl: uploadedUrl,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Member' : 'Add Family Member'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo picker
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: _photoFile != null
                            ? FileImage(_photoFile!)
                            : (_photoUrl != null
                                ? NetworkImage(_photoUrl!)
                                : null) as ImageProvider?,
                        child: (_photoFile == null && _photoUrl == null)
                            ? const Icon(Icons.person_rounded,
                                size: 40, color: AppColors.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Add photo (optional)',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter')),
              ),
              const SizedBox(height: 28),

              // Name
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g. Aryan Ahmed',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              // Relationship
              const Text('Relationship',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.relationships.map((r) {
                  final sel = _relationship == r;
                  return GestureDetector(
                    onTap: () => setState(() => _relationship = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.muted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(r,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: sel
                                  ? Colors.white
                                  : AppColors.foreground,
                              fontFamily: 'Inter')),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Age
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age (optional)',
                  hintText: 'e.g. 8',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final age = int.tryParse(v.trim());
                  if (age == null || age < 0 || age > 130) {
                    return 'Enter a valid age';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Save Changes' : 'Add Member',
                          style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600)),
                ),
              ),

              // Delete option for edit mode
              if (_isEdit) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _confirmDelete(context),
                    child: const Text('Remove this member',
                        style: TextStyle(
                            color: AppColors.destructive,
                            fontFamily: 'Inter')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Member',
            style: TextStyle(fontFamily: 'Inter')),
        content: Text(
            'Remove ${widget.existing!.name} and all their medicine records?',
            style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref
                  .read(familyMemberNotifierProvider.notifier)
                  .delete(widget.uid, widget.existing!.id);
              if (mounted) Navigator.pop(context, 'deleted');
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
