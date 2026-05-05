import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/config/ai_config.dart';
import '../core/constants/app_constants.dart';

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
      name:      (map['name']      as String?)?.trim() ?? '',
      dosage:    (map['dosage']    as String?)?.trim().isNotEmpty == true
                     ? (map['dosage'] as String).trim()
                     : 'As directed',
      frequency: _normalise((map['frequency'] as String?) ?? ''),
      duration:  (map['duration']  as String?)?.trim(),
      notes:     (map['notes']     as String?)?.trim(),
      uncertain: (map['uncertain'] as bool?)   ?? false,
    );
  }

  // Maps whatever Claude returns to one of the five AppConstants freq values.
  static String _normalise(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('twice') || l.contains('two') || l == 'bd' || l == 'bid') {
      return AppConstants.freqTwice;
    }
    if (l.contains('three') || l.contains('thrice') || l == 'tds' || l == 'tid') {
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

  /// Sends [imageFile] to Claude Vision and returns structured prescription data.
  /// Throws on network / API error so the caller can decide on fallback behaviour.
  Future<PrescriptionScanResult> scan(File imageFile) async {
    if (!isConfigured) {
      throw Exception('Claude API key not configured.');
    }

    final bytes  = await imageFile.readAsBytes();
    final b64    = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type':      'application/json',
            'x-api-key':         kClaudeApiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model':      _model,
            'max_tokens': _maxTokens,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type':       'base64',
                      'media_type': 'image/jpeg',
                      'data':        b64,
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

    final body    = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = (body['content'] as List).first['text'] as String;

    // Claude is asked to return bare JSON, but add a safety net for fences.
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
    if (jsonMatch == null) throw Exception('Unexpected AI response format');

    final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

    return PrescriptionScanResult(
      doctorName: (parsed['doctor_name'] as String?)?.trim().isNotEmpty == true
          ? (parsed['doctor_name'] as String).trim()
          : null,
      medicines: ((parsed['medicines'] as List?) ?? [])
          .map((e) => ScannedMedicine.fromMap(e as Map<String, dynamic>))
          .where((m) => m.name.isNotEmpty)
          .toList(),
    );
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
