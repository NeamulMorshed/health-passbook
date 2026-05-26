import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../core/config/ai_config.dart';
import '../core/constants/app_constants.dart';
import 'drug_database_service.dart';
import 'rxnorm_service.dart';

// ── Result models ─────────────────────────────────────────────────────────────

class PrescriptionScanResult {
  final String? doctorName;
  final List<ScannedMedicine> medicines;

  const PrescriptionScanResult({
    this.doctorName,
    required this.medicines,
  });

  bool get hasData => medicines.isNotEmpty;
}

class ScannedMedicine {
  final String name;
  final String dosage;
  final String frequency;
  final String? duration;
  final String? notes;
  final bool uncertain;

  const ScannedMedicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    this.duration,
    this.notes,
    this.uncertain = false,
  });

  factory ScannedMedicine.fromMap(Map<String, dynamic> map) {
    return ScannedMedicine(
      name: (map['name'] as String?)?.trim() ?? '',
      dosage: (map['dosage'] as String?)?.trim().isNotEmpty == true
          ? (map['dosage'] as String).trim()
          : 'As directed',
      frequency: _normalise((map['frequency'] as String?) ?? ''),
      duration: (map['duration'] as String?)?.trim(),
      notes: (map['notes'] as String?)?.trim(),
      uncertain: (map['uncertain'] as bool?) ?? false,
    );
  }

  // Maps whatever Claude returns to one of the five AppConstants freq values.
  static String _normalise(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('twice') || l.contains('two') || l == 'bd' || l == 'bid') {
      return AppConstants.freqTwice;
    }
    if (l.contains('three') ||
        l.contains('thrice') ||
        l == 'tds' ||
        l == 'tid') {
      return AppConstants.freqThrice;
    }
    if (l.contains('need') || l == 'prn' || l == 'sos') {
      return AppConstants.freqAsNeeded;
    }
    if (l.contains('week')) return AppConstants.freqWeekly;
    return AppConstants.freqOnce;
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class PrescriptionAiService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  // Sonnet has vision capability and is cost-effective for image tasks.
  static const _model = 'claude-sonnet-4-6';
  static const _maxTokens = 1500;

  bool get isConfigured => kClaudeApiKey != 'YOUR_CLAUDE_API_KEY_HERE';

  // PR1: Detect media type from file extension.
  String _mediaType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'heic': 'image/heic',
    };
    return map[ext] ?? 'image/jpeg';
  }

  /// Sends [imageFile] to Claude Vision and returns structured prescription data.
  /// Throws on network / API error so the caller can decide on fallback behaviour.
  Future<PrescriptionScanResult> scan(File imageFile) async {
    if (!isConfigured) {
      throw Exception('Claude API key not configured.');
    }

    // PR2: Check file size and compress if over 4 MB.
    final fileSize = await imageFile.length();
    File processFile = imageFile;
    if (fileSize > 4 * 1024 * 1024) {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        '${imageFile.parent.path}/compressed_${imageFile.uri.pathSegments.last}',
        quality: 70,
        minWidth: 1920,
        minHeight: 1920,
      );
      if (compressed != null) processFile = File(compressed.path);
    }

    final bytes = await processFile.readAsBytes();
    final b64 = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': kClaudeApiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': _maxTokens,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      // PR1: Use dynamic media type instead of hardcoded 'image/jpeg'.
                      'media_type': _mediaType(imageFile),
                      'data': b64,
                    },
                  },
                  {'type': 'text', 'text': _prompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('AI scan failed — HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = (body['content'] as List).first['text'] as String;

    // Claude is asked to return bare JSON, but add a safety net for fences.
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
    if (jsonMatch == null) throw Exception('Unexpected AI response format');

    final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

    final db = DrugDatabaseService.instance;
    await db.load();

    final rawMedicines = ((parsed['medicines'] as List?) ?? [])
        .map((e) => ScannedMedicine.fromMap(e as Map<String, dynamic>))
        .where((m) => m.name.isNotEmpty)
        .toList();

    // Enrich each medicine: offline DB first, RxNorm API fallback.
    // Both lookups are safe — any failure silently preserves the raw AI name.
    final medicines = await Future.wait(rawMedicines.map(_enrich));

    return PrescriptionScanResult(
      doctorName: (parsed['doctor_name'] as String?)?.trim().isNotEmpty == true
          ? (parsed['doctor_name'] as String).trim()
          : null,
      medicines: medicines,
    );
  }

  // ── Enrichment pipeline ───────────────────────────────────────────────────

  static final _db = DrugDatabaseService.instance;

  /// Resolves [m]'s name against the offline drug DB, then (on miss) RxNorm.
  /// Always returns a valid ScannedMedicine — worst case the raw AI output.
  static Future<ScannedMedicine> _enrich(ScannedMedicine m) async {
    // 1. Offline Levenshtein match (fast, no network).
    final offlineMatch = _db.findBestMatch(m.name);
    if (offlineMatch != null) {
      return ScannedMedicine(
        name: _db.canonicalName(offlineMatch),
        dosage: m.dosage,
        frequency: m.frequency,
        duration: m.duration,
        notes: m.notes,
        uncertain: m.uncertain && offlineMatch.confidence < 0.92,
      );
    }

    // 2. RxNorm API fallback (network, Firestore-cached after first lookup).
    final rxGeneric = await RxNormService.instance.lookupGeneric(m.name);
    if (rxGeneric != null) {
      return ScannedMedicine(
        name: rxGeneric,
        dosage: m.dosage,
        frequency: m.frequency,
        duration: m.duration,
        notes: m.notes,
        uncertain: false,
      );
    }

    // 3. No match — keep the raw AI name as-is.
    return m;
  }

  // ── Prompt ────────────────────────────────────────────────────────────────

  static const _prompt = r'''
You are a medical prescription reader specialising in South Asian — particularly Bangladeshi — prescriptions, including handwritten ones in English, Bengali, or mixed script.

FREQUENCY MAPPING (use these exact strings only):
• OD / 1× / 1+0+0 / once daily          → "Once daily"
• BD / BID / 1+0+1 / twice daily         → "Twice daily"
• TDS / TID / 1+1+1 / three times daily  → "Three times daily"
• PRN / SOS / as needed / when required  → "As needed"
• Weekly / OW / once a week              → "Weekly"

COMMON BANGLADESHI BRAND → GENERIC MAPPINGS (show both if visible):
Napa / Ace / Typenol   → Paracetamol
Seclo / Losectil       → Omeprazole
Maxpro                 → Esomeprazole
Amodis                 → Metronidazole
Fexo / Fexotabs        → Fexofenadine
Xeldrin / Cetriz       → Cetirizine
Tryptanol              → Amitriptyline
Glucophage / Diaphage  → Metformin
Atorva / Lipitor       → Atorvastatin
Amlodip / Norvasc      → Amlodipine

INSTRUCTIONS:
1. Extract every medicine listed on the prescription.
2. Prefer the generic name; append the brand name in parentheses if both are visible (e.g. "Paracetamol (Napa)").
3. Extract dosage exactly as written (e.g. "500mg", "1 tablet", "5ml").
4. Map frequency using the table above.
5. Extract duration if written (e.g. "7 days", "1 month").
6. Extract special instructions as notes (e.g. "after meals", "at bedtime").
7. Set uncertain: true if you cannot clearly read the name or dosage.
8. Extract the prescribing doctor's full name (without "Dr." prefix). Return null if not visible.

Return ONLY valid JSON — no markdown fences, no explanation, no extra text:
{
  "doctor_name": "Full name or null",
  "medicines": [
    {
      "name": "Generic (Brand) or just Generic",
      "dosage": "e.g. 500mg",
      "frequency": "Once daily | Twice daily | Three times daily | As needed | Weekly",
      "duration": "e.g. 7 days or null",
      "notes": "e.g. after meals or null",
      "uncertain": false
    }
  ]
}
''';
}
