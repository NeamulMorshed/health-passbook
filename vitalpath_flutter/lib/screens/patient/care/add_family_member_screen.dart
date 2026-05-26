import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
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

class _AddFamilyMemberScreenState extends ConsumerState<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  String? _relationship;
  DateTime? _dob;
  String? _photoUrl;
  File? _photoFile;
  bool _photoRemoved = false;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _relationship = m?.relationship;
    _dob = m?.dateOfBirth;
    _photoUrl = m?.photoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 10),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera01,
                  color: AppColors.textPrimary,
                  size: 20),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_photoFile != null || (_photoUrl != null && !_photoRemoved))
              ListTile(
                leading: HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    color: AppColors.destructive,
                    size: 18),
                title: const Text('Remove photo',
                    style: TextStyle(color: AppColors.destructive)),
                onTap: () => Navigator.pop(ctx, null),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (choice == null) {
      if (_photoFile != null || (_photoUrl != null && !_photoRemoved)) {
        setState(() {
          _photoFile = null;
          _photoRemoved = true;
        });
      }
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: choice,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (picked == null) return;
    setState(() {
      _photoFile = File(picked.path);
      _photoRemoved = false;
    });
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_photoRemoved) return null;
    if (_photoFile == null) return _photoUrl;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('${AppConstants.storageProfilePhotos}/family/$uid/$ts.jpg');
    await ref.putFile(_photoFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_relationship == null) {
      AppSnackBar.info(context, 'Please select a relationship');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uploadedUrl = await _uploadPhoto(widget.uid);
      final notifier = ref.read(familyMemberNotifierProvider.notifier);
      if (_isEdit) {
        final updated = FamilyMember(
          id: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          relationship: _relationship!,
          dateOfBirth: _dob,
          photoUrl: uploadedUrl,
          createdAt: widget.existing!.createdAt,
        );
        await notifier.update(widget.uid, updated);
      } else {
        await notifier.add(
          widget.uid,
          name: _nameCtrl.text.trim(),
          relationship: _relationship!,
          dateOfBirth: _dob,
          photoUrl: uploadedUrl,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackBar.error(context, 'Failed to save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        _photoFile != null || (_photoUrl != null && !_photoRemoved);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
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
                            : (!_photoRemoved && _photoUrl != null
                                ? NetworkImage(_photoUrl!)
                                : null) as ImageProvider?,
                        child: !hasPhoto
                            ? HugeIcon(
                                icon: HugeIcons.strokeRoundedUser,
                                color: AppColors.primary,
                                size: 40)
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
                          child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCamera01,
                              color: Colors.white,
                              size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  hasPhoto ? 'Tap to change or remove' : 'Add photo (optional)',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground),
                ),
              ),
              const SizedBox(height: 28),

              // Name
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g. Aryan Ahmed',
                  prefixIcon: HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      color: AppColors.textSecondary,
                      size: 24),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              // Date of birth
              InkWell(
                onTap: _pickDob,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth (optional)',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dob != null
                              ? DateFormat('d MMM yyyy').format(_dob!)
                              : 'Tap to select',
                          style: TextStyle(
                            fontSize: 14,
                            color: _dob != null
                                ? AppColors.foreground
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      if (_dob != null)
                        GestureDetector(
                          onTap: () => setState(() => _dob = null),
                          child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                              color: AppColors.mutedForeground,
                              size: 16),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Relationship
              Row(
                children: [
                  const Text('Relationship',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedForeground)),
                  const Text(' *',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.destructive)),
                ],
              ),
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
                          color: sel ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(r,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color:
                                  sel ? Colors.white : AppColors.foreground)),
                    ),
                  );
                }).toList(),
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
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        style: TextStyle(color: AppColors.destructive)),
                  ),
                ),
              ],

              // Invite as linked account — only shown in add mode
              if (!_isEdit) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                const Text(
                  'They use Omra?',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Link their account so you can both see each other\'s care circle.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.push('/invite-family'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero),
                    child: const Text(
                      'Invite as a linked account →',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
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
        title: const Text('Delete Member Permanently'),
        content: Text(
            'This will permanently delete ${widget.existing!.name} and all their health data, including medicines and history. This action cannot be undone.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive),
                onPressed: () async {
                  final nav = Navigator.of(context);
                  Navigator.pop(dialogCtx);
                  try {
                    await ref
                        .read(familyMemberNotifierProvider.notifier)
                        .delete(widget.uid, widget.existing!.id);
                    if (mounted) nav.pop('deleted');
                  } catch (_) {
                    if (mounted) {
                      AppSnackBar.error(context, 'Failed to delete member. Please try again.');
                    }
                  }
                },
                child: const Text('Delete Permanently'),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
