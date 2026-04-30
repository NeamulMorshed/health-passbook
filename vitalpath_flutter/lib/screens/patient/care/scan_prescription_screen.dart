import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/patient_provider.dart';

// ── Data class for one entry in the review form ───────────────────────────────

class _ScannedEntry {
  final TextEditingController name;
  final TextEditingController dosage;
  final TextEditingController notes;
  String frequency;
  bool isUncertain;

  _ScannedEntry({
    String initialName = '',
    String initialDosage = '',
    String initialNotes = '',
    this.frequency = AppConstants.freqOnce,
    this.isUncertain = false,
  })  : name = TextEditingController(text: initialName),
        dosage = TextEditingController(text: initialDosage),
        notes = TextEditingController(text: initialNotes);

  void dispose() {
    name.dispose();
    dosage.dispose();
    notes.dispose();
  }
}

// ── Screen states ─────────────────────────────────────────────────────────────

enum _ScanState { capture, processing, review }

// ── Main screen ───────────────────────────────────────────────────────────────

class ScanPrescriptionScreen extends ConsumerStatefulWidget {
  final String uid;
  const ScanPrescriptionScreen({super.key, required this.uid});

  @override
  ConsumerState<ScanPrescriptionScreen> createState() =>
      _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState
    extends ConsumerState<ScanPrescriptionScreen> {
  _ScanState _state = _ScanState.capture;
  File? _imageFile;
  String? _uploadedPhotoUrl;
  final List<_ScannedEntry> _entries = [];
  bool _isSaving = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Image pick ────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _imageFile = file;
      _state = _ScanState.processing;
    });
    await _processImage(file);
  }

  // ── OCR + upload ──────────────────────────────────────────────────────────

  Future<void> _processImage(File file) async {
    try {
      // Upload first so the URL is available regardless of OCR result
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('${AppConstants.storagePrescriptions}/${widget.uid}/scan_$ts.jpg');
      await ref.putFile(file);
      _uploadedPhotoUrl = await ref.getDownloadURL();

      // Run OCR
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(file);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final parsed = _parsePrescription(result.text);

      setState(() {
        _entries.clear();
        if (parsed.isEmpty) {
          // Fallback: one blank entry, user fills in manually
          _entries.add(_ScannedEntry());
        } else {
          _entries.addAll(parsed);
        }
        _state = _ScanState.review;
      });
    } catch (_) {
      setState(() {
        _entries.clear();
        _entries.add(_ScannedEntry());
        _state = _ScanState.review;
      });
    }
  }

  // ── Simple prescription parser ────────────────────────────────────────────

  List<_ScannedEntry> _parsePrescription(String text) {
    final entries = <_ScannedEntry>[];
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Matches dosage patterns: 500mg, 10 ml, 0.5mcg, 100IU, etc.
    final dosageRx = RegExp(
        r'\b\d+\.?\d*\s*(mg|ml|mcg|g\b|iu|units?|tablet|cap|tab)\b',
        caseSensitive: false);

    final freqMap = {
      RegExp(r'\b(once daily|od|1x|once a day|1 time)\b',
          caseSensitive: false): AppConstants.freqOnce,
      RegExp(r'\b(twice|bd|bid|twice daily|2x|2 times)\b',
          caseSensitive: false): AppConstants.freqTwice,
      RegExp(r'\b(tds|tid|3x|3 times|thrice|three times)\b',
          caseSensitive: false): AppConstants.freqThrice,
      RegExp(r'\b(as needed|prn|sos|when needed|on demand)\b',
          caseSensitive: false): AppConstants.freqAsNeeded,
      RegExp(r'\b(weekly|once a week|ow|per week)\b',
          caseSensitive: false): AppConstants.freqWeekly,
    };

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final dosageMatch = dosageRx.firstMatch(line);
      if (dosageMatch == null) continue;

      final dosage = dosageMatch.group(0)!.trim();

      // Name = text before the dosage, cleaned up
      final rawName = line.substring(0, dosageMatch.start).trim();
      final name = rawName
          .replaceAll(RegExp(r'^\d+[\.\)]\s*'), '') // remove "1. " numbering
          .replaceAll(RegExp(r'^[-•*]\s*'), '')       // remove bullet
          .trim();

      // Frequency: check current line then the next two lines
      String freq = AppConstants.freqOnce;
      bool freqFound = false;
      final checkLines = [
        line,
        if (i + 1 < lines.length) lines[i + 1],
        if (i + 2 < lines.length) lines[i + 2],
      ];
      for (final cl in checkLines) {
        for (final entry in freqMap.entries) {
          if (entry.key.hasMatch(cl)) {
            freq = entry.value;
            freqFound = true;
            break;
          }
        }
        if (freqFound) break;
      }

      // Mark as uncertain when name is very short or empty
      final uncertain = name.length < 3 || dosage.isEmpty;

      if (name.isNotEmpty || dosage.isNotEmpty) {
        entries.add(_ScannedEntry(
          initialName: name,
          initialDosage: dosage,
          frequency: freq,
          isUncertain: uncertain,
        ));
      }
    }

    return entries;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Validate: at least one entry must have a name
    final valid = _entries.any((e) => e.name.text.trim().isNotEmpty);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one medicine name.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final entry in _entries) {
        final name = entry.name.text.trim();
        if (name.isEmpty) continue;
        await ref.read(medicineNotifierProvider.notifier).add(
              widget.uid,
              name: name,
              dosage: entry.dosage.text.trim().isEmpty
                  ? 'As directed'
                  : entry.dosage.text.trim(),
              frequency: entry.frequency,
              notes: entry.notes.text.trim().isEmpty
                  ? null
                  : entry.notes.text.trim(),
              scannedPhotoUrl: _uploadedPhotoUrl,
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

  // ── State A: Capture ──────────────────────────────────────────────────────

  Widget _buildCapture() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan your prescription',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a photo or upload from your gallery.\nWe\'ll read the medicine details for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                  fontFamily: 'Inter'),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take a Photo'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose from Gallery'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter')),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Add medicine manually instead',
                  style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter',
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── State B: Processing ───────────────────────────────────────────────────

  Widget _buildProcessing() {
    return Stack(
      children: [
        if (_imageFile != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            ),
          ),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 24),
              Text(
                'Reading prescription…',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter'),
              ),
              SizedBox(height: 8),
              Text(
                'This usually takes a few seconds.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── State C/D: Review (with or without pre-filled data) ───────────────────

  Widget _buildReview() {
    final hasOcrData = _entries.any((e) =>
        e.name.text.isNotEmpty || e.dosage.text.isNotEmpty);

    return Column(
      children: [
        // OCR result banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: hasOcrData
              ? AppColors.success.withValues(alpha: 0.08)
              : AppColors.warning.withValues(alpha: 0.08),
          child: Row(children: [
            Icon(
              hasOcrData
                  ? Icons.auto_fix_high_rounded
                  : Icons.warning_amber_rounded,
              size: 16,
              color: hasOcrData ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasOcrData
                    ? 'We found ${_entries.length} medicine${_entries.length == 1 ? '' : 's'}. Review and correct if needed.'
                    : 'Couldn\'t read the prescription clearly. Please fill in the details manually.',
                style: TextStyle(
                  fontSize: 12,
                  color: hasOcrData ? AppColors.success : AppColors.warning,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // Prescription photo thumbnail
              if (_imageFile != null) ...[
                GestureDetector(
                  onTap: () => _showFullPhoto(context),
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      image: DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Tap to view full',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontFamily: 'Inter')),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Medicine entry cards
              ...List.generate(_entries.length, (i) => _EntryCard(
                    index: i,
                    entry: _entries[i],
                    canRemove: _entries.length > 1,
                    onRemove: () => setState(() {
                      _entries[i].dispose();
                      _entries.removeAt(i);
                    }),
                    onChanged: () => setState(() {}),
                  )),

              // Add another medicine
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _entries.add(_ScannedEntry())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add another medicine',
                    style: TextStyle(fontFamily: 'Inter')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullPhoto(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_imageFile!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // ── Save button floats above the list ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan Prescription'),
        actions: [
          if (_state == _ScanState.review)
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() {
                        _imageFile = null;
                        _uploadedPhotoUrl = null;
                        for (final e in _entries) {
                          e.dispose();
                        }
                        _entries.clear();
                        _state = _ScanState.capture;
                      }),
              child: const Text('Retake',
                  style: TextStyle(
                      color: AppColors.primary, fontFamily: 'Inter')),
            ),
        ],
      ),
      body: switch (_state) {
        _ScanState.capture    => _buildCapture(),
        _ScanState.processing => _buildProcessing(),
        _ScanState.review     => _buildReview(),
      },
      floatingActionButton: _state == _ScanState.review
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _save,
              backgroundColor: AppColors.primary,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving…' : 'Save Medicines',
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'Inter'),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Entry card: one medicine in the review form ───────────────────────────────

class _EntryCard extends StatefulWidget {
  final int index;
  final _ScannedEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _EntryCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final uncertain = entry.isUncertain;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: uncertain ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medication_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text('Medicine ${widget.index + 1}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter')),
              if (uncertain) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Check this',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter')),
                ),
              ],
              const Spacer(),
              if (widget.canRemove)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.mutedForeground),
                ),
            ]),
            const SizedBox(height: 14),

            // Medicine name
            TextField(
              controller: entry.name,
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                labelText: 'Medicine Name *',
                hintText: 'e.g. Metformin',
                filled: true,
                fillColor: uncertain && entry.name.text.isEmpty
                    ? AppColors.warning.withValues(alpha: 0.05)
                    : null,
              ),
            ),
            const SizedBox(height: 10),

            // Dosage
            TextField(
              controller: entry.dosage,
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                labelText: 'Dosage',
                hintText: 'e.g. 500mg',
                filled: true,
                fillColor: uncertain && entry.dosage.text.isEmpty
                    ? AppColors.warning.withValues(alpha: 0.05)
                    : null,
              ),
            ),
            const SizedBox(height: 10),

            // Frequency dropdown
            DropdownButtonFormField<String>(
              initialValue: entry.frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: [
                AppConstants.freqOnce,
                AppConstants.freqTwice,
                AppConstants.freqThrice,
                AppConstants.freqAsNeeded,
                AppConstants.freqWeekly,
              ]
                  .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f,
                          style: const TextStyle(fontFamily: 'Inter'))))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => entry.frequency = v);
                  widget.onChanged();
                }
              },
            ),
            const SizedBox(height: 10),

            // Notes (optional)
            TextField(
              controller: entry.notes,
              onChanged: (_) => widget.onChanged(),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Take after meals',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
