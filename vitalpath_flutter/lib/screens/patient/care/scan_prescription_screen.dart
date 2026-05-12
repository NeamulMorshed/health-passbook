import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/drug_interaction.dart';
import '../../../models/family_member.dart';
import '../../../services/drug_interaction_service.dart';
import '../../../services/prescription_ai_service.dart';
import '../../../widgets/interaction_warning_card.dart';

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
  final FamilyMember? familyMember;
  const ScanPrescriptionScreen({super.key, required this.uid, this.familyMember});

  @override
  ConsumerState<ScanPrescriptionScreen> createState() =>
      _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState
    extends ConsumerState<ScanPrescriptionScreen> {
  _ScanState _state = _ScanState.capture;
  File? _imageFile;
  String? _uploadedPhotoUrl;
  String? _prescribedBy;
  bool _usedAi = false;
  final List<_ScannedEntry> _entries = [];
  bool _isSaving = false;

  // Phase C — drug interaction check
  List<DrugInteraction> _interactions = [];
  bool _checkingInteractions = false;
  bool _interactionCheckDone = false;

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
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to scan prescriptions.')),
          );
        }
        return;
      }
    }
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

  // ── AI + upload ───────────────────────────────────────────────────────────

  Future<void> _processImage(File file) async {
    // C-SP1: do NOT upload to Storage here — upload happens in _save() after
    // the user confirms they want to keep the result.
    try {
      // ── Primary: Claude Vision ─────────────────────────────────────────────
      final aiService = PrescriptionAiService();
      if (aiService.isConfigured) {
        try {
          final result = await aiService.scan(file);
          if (result.hasData) {
            _prescribedBy = result.doctorName;
            _usedAi = true;
            setState(() {
              _entries
                ..clear()
                ..addAll(result.medicines.map((m) {
                  final noteParts = [
                    if (m.duration != null) 'Duration: ${m.duration}',
                    if (m.notes != null) m.notes!,
                  ];
                  return _ScannedEntry(
                    initialName:   m.name,
                    initialDosage: m.dosage,
                    initialNotes:  noteParts.join(' · '),
                    frequency:     m.frequency,
                    isUncertain:   m.uncertain,
                  );
                }));
              _state = _ScanState.review;
            });
            unawaited(_checkInteractions());
            return;
          }
        } catch (_) {
          // AI failed — fall through to MLKit.
        }
      }

      // ── Fallback: MLKit OCR + regex ────────────────────────────────────────
      _usedAi = false;
      // H-SP2: close TextRecognizer in a finally block
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(file);
      String ocrText = '';
      try {
        final ocrResult = await recognizer.processImage(inputImage);
        ocrText = ocrResult.text;
      } finally {
        await recognizer.close();
      }
      final parsed = _parsePrescription(ocrText);

      setState(() {
        _entries.clear();
        _entries.addAll(parsed.isNotEmpty ? parsed : [_ScannedEntry()]);
        _state = _ScanState.review;
      });
      unawaited(_checkInteractions());
    } catch (_) {
      setState(() {
        _entries..clear()..add(_ScannedEntry());
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

    // Extract prescribing doctor name from full text
    final doctorRx = RegExp(
        r'\bDr\.?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
        caseSensitive: false);
    final doctorMatch = doctorRx.firstMatch(text);
    _prescribedBy = doctorMatch?.group(1)?.trim();

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

  // ── Drug interaction check ────────────────────────────────────────────────

  /// Runs in the background after scan completes — does not block the review UI.
  /// Checks new medicines against each other AND against existing saved medicines.
  Future<void> _checkInteractions() async {
    // C-SP3: snapshot the entry list so stale results from a prior scan can be discarded
    final entriesSnapshot = List<_ScannedEntry>.from(_entries);

    final newNames = entriesSnapshot
        .map((e) => e.name.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (newNames.isEmpty) return; // Need ≥1 new + possibly existing to form a pair.

    if (!mounted) return;
    setState(() {
      _checkingInteractions = true;
      _interactionCheckDone = false;
    });

    try {
      final existingNames =
          (ref.read(medicinesProvider(widget.uid)).valueOrNull ?? [])
              .map((m) => m.name)
              .toList();
      final allNames = [...newNames, ...existingNames];

      final result = await DrugInteractionService.instance
          .checkInteractions(allNames);

      if (!mounted) return;
      // C-SP3: discard result if entries changed (user retook the photo)
      if (_entries.length != entriesSnapshot.length) return;
      setState(() {
        _interactions = result;
        _interactionCheckDone = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _interactionCheckDone = true;
        });
      }
    } finally {
      if (mounted) setState(() => _checkingInteractions = false);
    }
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

    // Check for duplicates against existing medicines
    final existingMeds = ref.read(medicinesProvider(widget.uid)).valueOrNull ?? [];
    final entryNames = _entries
        .map((e) => e.name.text.trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toList();
    final duplicateNames = entryNames
        .where((n) => existingMeds.any((m) => m.name.toLowerCase() == n))
        .map((n) => n[0].toUpperCase() + n.substring(1))
        .toList();

    if (duplicateNames.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Duplicate Medicines'),
          content: Text(
              '${duplicateNames.join(', ')} ${duplicateNames.length == 1 ? 'already exists' : 'already exist'} in your medicines. Add anyway?'),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Add Anyway')),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                ),
              ],
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    // H-SP1: use try/catch/finally so _isSaving is always reset
    try {
      setState(() => _isSaving = true);

      // C-SP1: upload to Storage NOW (only on confirmed save), not during scan
      if (_imageFile != null && _uploadedPhotoUrl == null) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final storageRef = FirebaseStorage.instance.ref(
            '${AppConstants.storagePrescriptions}/${widget.uid}/scan_$ts.jpg');
        await storageRef.putFile(_imageFile!);
        _uploadedPhotoUrl = await storageRef.getDownloadURL();
      }

      final fm = widget.familyMember;
      for (final entry in _entries) {
        final name = entry.name.text.trim();
        if (name.isEmpty) continue;
        final dosage = entry.dosage.text.trim().isEmpty
            ? 'As directed'
            : entry.dosage.text.trim();
        final notes = entry.notes.text.trim().isEmpty
            ? null
            : entry.notes.text.trim();
        if (fm != null) {
          await ref.read(familyMedicinePatchProvider).add(
                widget.uid, fm.id,
                name: name,
                dosage: dosage,
                frequency: entry.frequency,
                notes: notes,
                prescribedBy: _prescribedBy,
                scannedPhotoUrl: _uploadedPhotoUrl,
              );
        } else {
          await ref.read(medicineNotifierProvider.notifier).add(
                widget.uid,
                name: name,
                dosage: dosage,
                frequency: entry.frequency,
                notes: notes,
                prescribedBy: _prescribedBy,
                scannedPhotoUrl: _uploadedPhotoUrl,
              );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Some medicines could not be saved: $e')),
        );
      }
    } finally {
      // H-SP1: always reset saving flag
      if (mounted) setState(() => _isSaving = false);
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
              child: HugeIcon(icon: HugeIcons.strokeRoundedBarcodeScan, color: AppColors.primary, size: 56),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan your prescription',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a photo or upload from your gallery.\nWe\'ll read the medicine details for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedCamera01, color: Colors.black, size: 20),
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
                        color: AppColors.mutedForeground)),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Add medicine manually instead',
                  style: TextStyle(
                      color: AppColors.mutedForeground,
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
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'This usually takes a few seconds.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground),
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
        // Scan result banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: hasOcrData
              ? AppColors.success.withValues(alpha: 0.08)
              : AppColors.warning.withValues(alpha: 0.08),
          child: Row(children: [
            Icon(
              hasOcrData
                  ? (_usedAi ? Icons.smart_toy_rounded : Icons.auto_fix_high_rounded)
                  : Icons.warning_amber_rounded,
              size: 16,
              color: hasOcrData ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasOcrData
                    ? '${_usedAi ? 'AI' : 'OCR'} found ${_entries.length} medicine${_entries.length == 1 ? '' : 's'}. Review and correct if needed.'
                    : 'Couldn\'t read the prescription clearly. Please fill in the details manually.',
                style: TextStyle(
                  fontSize: 12,
                  color: hasOcrData ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
        ),

        // Interaction warnings (loading → clear → list)
        if (_checkingInteractions || _interactionCheckDone)
          InteractionWarningCard(
            interactions: _interactions,
            isLoading: _checkingInteractions,
            isDone: _interactionCheckDone,
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
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Tap to view full',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white)),
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
                icon: HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: Colors.black, size: 18),
                label: const Text('Add another medicine'),
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
      backgroundColor: AppColors.pageBackground,
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
                        // H-SP3: reset interaction state on retake
                        _checkingInteractions = false;
                        _interactionCheckDone = false;
                        _interactions = [];
                      }),
              child: const Text('Retake',
                  style: TextStyle(color: AppColors.primary)),
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
                  : HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: Colors.white, size: 16),
              label: Text(
                _isSaving ? 'Saving…' : 'Save Medicines',
                style: const TextStyle(color: Colors.white),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BentoCard(
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
                child: const Icon(Icons.medication_outlined,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text('Medicine ${widget.index + 1}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              if (uncertain) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Check this',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              if (widget.canRemove)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: AppColors.mutedForeground, size: 18),
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
                      child: Text(f)))
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
