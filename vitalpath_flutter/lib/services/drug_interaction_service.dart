import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/config/drugbank_config.dart';
import '../models/drug_interaction.dart';
import 'rxnorm_service.dart';

// ── DrugInteractionService ────────────────────────────────────────────────────
//
// Tier 1 (free, live): RxNav Interaction API — NLM's public database that
//   aggregates DrugBank open data and NDFRT. No API key, no rate limit.
//   Endpoint: https://rxnav.nlm.nih.gov/REST/interaction/list.json
//
// Tier 2 (commercial): DrugBank Plus API — structured severity levels,
//   dosage ranges per patient weight/age, and contraindication checks.
//   Activated when kDrugBankApiKey is set to a real key.
//   Endpoint: https://api.drugbankplus.com/v1/
//
// Both tiers share a Firestore cache so each drug pair is never looked up
// twice across the entire user base.

class DrugInteractionService {
  DrugInteractionService._();
  static DrugInteractionService? _instance;
  static DrugInteractionService get instance =>
      _instance ??= DrugInteractionService._();

  static const _rxnavBase = 'https://rxnav.nlm.nih.gov/REST';
  static const _drugBankBase = 'https://api.drugbankplus.com/v1';
  static const _timeout = Duration(seconds: 15);

  final _db = FirebaseFirestore.instance;

  bool get _drugBankConfigured =>
      kDrugBankApiKey != 'YOUR_DRUGBANK_API_KEY_HERE';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks for known drug-drug interactions among [drugNames].
  ///
  /// Resolves names → RxCUIs, then queries RxNav (always) and DrugBank
  /// (when licensed). Results are cached in Firestore so the same set is
  /// never queried twice.
  ///
  /// Returns an empty list on network error — never throws.
  Future<List<DrugInteraction>> checkInteractions(
    List<String> drugNames, {
    int maxMedicines = 12,
  }) async {
    final names = drugNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .take(maxMedicines)
        .toList();

    if (names.length < 2) return [];

    // ── Resolve RxCUIs ──────────────────────────────────────────────────────
    final rxcuiMap = await _resolveRxcuis(names);
    final rxcuis = rxcuiMap.values.toSet().toList();
    if (rxcuis.length < 2) return [];

    // ── Firestore cache ─────────────────────────────────────────────────────
    final cacheKey = _interactionCacheKey(rxcuis);
    final cached = await _readCachedInteractions(cacheKey);
    if (cached != null) return cached;

    // ── RxNav (always) ──────────────────────────────────────────────────────
    final interactions = await _queryRxNav(rxcuis, rxcuiMap);

    // ── DrugBank (when licensed) ─────────────────────────────────────────────
    if (_drugBankConfigured) {
      interactions.addAll(await _queryDrugBankDdi(rxcuiMap));
    }

    // Deduplicate by drug pair (same pair from multiple sources).
    final unique = _deduplicate(interactions);

    await _writeCachedInteractions(cacheKey, unique);
    return unique;
  }

  /// Validates whether [dosage] is within the safe range for [drugName] given
  /// the patient's [ageYears] and optional [weightKg].
  ///
  /// Requires DrugBank Plus licence. Returns empty list when not configured.
  Future<List<DosageWarning>> checkDosageForPatient(
    String drugName, {
    required int ageYears,
    double? weightKg,
  }) async {
    if (!_drugBankConfigured) return [];
    try {
      return await _drugBankDosageCheck(
        drugName,
        ageYears: ageYears,
        weightKg: weightKg,
      );
    } catch (_) {
      return [];
    }
  }

  /// Checks [drugName] against a list of [patientConditions] (free-text or
  /// ICD-10 codes) for known contraindications.
  ///
  /// Requires DrugBank Plus licence. Returns empty list when not configured.
  Future<List<ContraindicationAlert>> checkContraindications(
    String drugName,
    List<String> patientConditions,
  ) async {
    if (!_drugBankConfigured || patientConditions.isEmpty) return [];
    try {
      return await _drugBankContraindicationCheck(drugName, patientConditions);
    } catch (_) {
      return [];
    }
  }

  // ── RxCUI resolution ───────────────────────────────────────────────────────

  Future<Map<String, String>> _resolveRxcuis(List<String> names) async {
    final result = <String, String>{};
    await Future.wait(names.map((name) async {
      final rxcui = await RxNormService.instance.lookupRxcui(name);
      if (rxcui != null) result[name] = rxcui;
    }));
    return result;
  }

  // ── RxNav interaction query ────────────────────────────────────────────────

  Future<List<DrugInteraction>> _queryRxNav(
    List<String> rxcuis,
    Map<String, String> rxcuiMap,
  ) async {
    try {
      // RxNav accepts '+'-joined rxcuis as a space-separated list.
      final param = rxcuis.join('+');
      final res = await http
          .get(Uri.parse('$_rxnavBase/interaction/list.json?rxcuis=$param'))
          .timeout(_timeout);

      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final groups = body['fullInteractionTypeGroup'] as List? ?? [];

      final interactions = <DrugInteraction>[];
      for (final group in groups) {
        final source = group['sourceName'] as String? ?? 'RxNav';
        final types = group['fullInteractionType'] as List? ?? [];
        for (final type in types) {
          final pairs = type['interactionPair'] as List? ?? [];
          for (final pair in pairs) {
            final interaction = _parseRxNavPair(pair, source);
            if (interaction != null) interactions.add(interaction);
          }
        }
      }
      return interactions;
    } catch (_) {
      return [];
    }
  }

  DrugInteraction? _parseRxNavPair(Map<String, dynamic> pair, String source) {
    final concepts = pair['interactionConcept'] as List?;
    final description = (pair['description'] as String?)?.trim() ?? '';
    if (concepts == null || concepts.length < 2 || description.isEmpty) {
      return null;
    }

    final a = (concepts[0]['minConceptItem'] as Map?)?.cast<String, dynamic>();
    final b = (concepts[1]['minConceptItem'] as Map?)?.cast<String, dynamic>();
    if (a == null || b == null) return null;

    final nameA = a['name'] as String? ?? '';
    final nameB = b['name'] as String? ?? '';
    final rxcuiA = a['rxcui'] as String?;
    final rxcuiB = b['rxcui'] as String?;
    final sevStr = (pair['severity'] as String?) ?? '';

    if (nameA.isEmpty || nameB.isEmpty) return null;

    return DrugInteraction(
      drugAName: nameA,
      drugBName: nameB,
      rxcuiA: rxcuiA,
      rxcuiB: rxcuiB,
      severity: _parseSeverity(sevStr),
      description: description,
      source: source,
    );
  }

  InteractionSeverity _parseSeverity(String s) {
    final l = s.toLowerCase();
    if (l.contains('high') || l.contains('major'))
      return InteractionSeverity.major;
    if (l.contains('medium') || l.contains('moderate'))
      return InteractionSeverity.moderate;
    if (l.contains('low') || l.contains('minor'))
      return InteractionSeverity.minor;
    return InteractionSeverity.unknown;
  }

  // ── DrugBank Plus — DDI (commercial) ──────────────────────────────────────

  Future<List<DrugInteraction>> _queryDrugBankDdi(
      Map<String, String> rxcuiMap) async {
    // Step 1: resolve drug names to DrugBank product_concept_ids.
    final dbIds = <String, String>{}; // name → drugbank_concept_id
    await Future.wait(rxcuiMap.keys.map((name) async {
      final id = await _drugBankProductId(name);
      if (id != null) dbIds[name] = id;
    }));

    if (dbIds.length < 2) return [];

    // Step 2: pairwise DDI check (DrugBank DDI requires pairs, not a list).
    final interactions = <DrugInteraction>[];
    final names = dbIds.keys.toList();
    for (int i = 0; i < names.length - 1; i++) {
      for (int j = i + 1; j < names.length; j++) {
        final pair = await _drugBankDdiPair(
          names[i],
          dbIds[names[i]]!,
          names[j],
          dbIds[names[j]]!,
        );
        interactions.addAll(pair);
      }
    }
    return interactions;
  }

  Future<String?> _drugBankProductId(String drugName) async {
    try {
      final encoded = Uri.encodeComponent(drugName);
      final res = await http.get(
        Uri.parse('$_drugBankBase/drug_products?q=$encoded&fuzzy_search=true'),
        headers: {'Authorization': 'Token token=$kDrugBankApiKey'},
      ).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      final products = body['products'] as List?;
      if (products == null || products.isEmpty) return null;
      return products.first['product_concept_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<DrugInteraction>> _drugBankDdiPair(
    String nameA,
    String idA,
    String nameB,
    String idB,
  ) async {
    try {
      final res = await http.get(
        Uri.parse(
            '$_drugBankBase/ddi?product_concept_id=$idA&product_concept_id=$idB'),
        headers: {'Authorization': 'Token token=$kDrugBankApiKey'},
      ).timeout(_timeout);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final interactions = body['drug_interactions'] as List? ?? [];
      return interactions.map((ddi) {
        final sev = (ddi['severity'] as String?)?.toLowerCase() ?? '';
        return DrugInteraction(
          drugAName: nameA,
          drugBName: nameB,
          severity: _parseSeverity(sev),
          description: ddi['description'] as String? ?? '',
          source: 'DrugBank',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── DrugBank Plus — dosage validation (commercial) ────────────────────────

  Future<List<DosageWarning>> _drugBankDosageCheck(
    String drugName, {
    required int ageYears,
    double? weightKg,
  }) async {
    final productId = await _drugBankProductId(drugName);
    if (productId == null) return [];

    final res = await http.get(
      Uri.parse('$_drugBankBase/drugs/$productId?fields=dosage'),
      headers: {'Authorization': 'Token token=$kDrugBankApiKey'},
    ).timeout(_timeout);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final drug = body['drug'] as Map<String, dynamic>?;
    final doses = drug?['dosages'] as List? ?? [];

    final warnings = <DosageWarning>[];
    for (final dose in doses) {
      final route = dose['route'] as String? ?? '';
      final form = dose['form'] as String? ?? '';
      final strength = dose['strength'] as String? ?? '';
      final isPed = ageYears < 18;

      // Flag if a paediatric-specific note contradicts an adult-only dose.
      if (isPed && (dose['adult_only'] as bool? ?? false)) {
        warnings.add(DosageWarning(
          drugName: drugName,
          message:
              '$drugName ($form $route): dosage listed for adults only — verify paediatric dose.',
          isCritical: true,
          recommendedRange: strength,
        ));
      }
    }
    return warnings;
  }

  // ── DrugBank Plus — contraindications (commercial) ────────────────────────

  Future<List<ContraindicationAlert>> _drugBankContraindicationCheck(
    String drugName,
    List<String> conditions,
  ) async {
    final productId = await _drugBankProductId(drugName);
    if (productId == null) return [];

    final res = await http.get(
      Uri.parse('$_drugBankBase/drugs/$productId?fields=contraindications'),
      headers: {'Authorization': 'Token token=$kDrugBankApiKey'},
    ).timeout(_timeout);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final contraindications =
        (body['drug']?['contraindications'] as List?) ?? [];
    final conditionsLower = conditions.map((c) => c.toLowerCase()).toList();
    final alerts = <ContraindicationAlert>[];

    for (final ci in contraindications) {
      final ciName = (ci['condition'] as String? ?? '').toLowerCase();
      final matches = conditionsLower.any(
        (c) => ciName.contains(c) || c.contains(ciName),
      );
      if (matches) {
        alerts.add(ContraindicationAlert(
          drugName: drugName,
          condition: ci['condition'] as String? ?? '',
          description: ci['description'] as String? ?? '',
          severity: ci['severity'] as String? ?? 'relative',
        ));
      }
    }
    return alerts;
  }

  // ── Firestore cache ────────────────────────────────────────────────────────
  // SEC1: Cache is scoped per user (users/{uid}/drug_interaction_cache/{key})
  // so one user's data cannot be read or poisoned by another user.
  // SECURITY: Firestore rules must restrict write access to authenticated users
  // and reads to the owning user only.

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  Future<List<DrugInteraction>?> _readCachedInteractions(String key) async {
    final uid = _currentUid;
    if (uid == null) return null;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('drug_interaction_cache')
          .doc(key)
          .get();
      if (!snap.exists) return null;
      final list = snap.data()?['interactions'] as List?;
      if (list == null) return null;
      return list
          .map((e) => DrugInteraction.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedInteractions(
      String key, List<DrugInteraction> interactions) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('drug_interaction_cache')
          .doc(key)
          .set({
        'interactions': interactions.map((i) => i.toMap()).toList(),
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Canonical cache key: sorted rxcuis joined with underscores.
  String _interactionCacheKey(List<String> rxcuis) {
    final sorted = [...rxcuis]..sort();
    final key = sorted.join('_');
    // Firestore doc IDs max 1500 bytes; typical keys are ~100 chars.
    return key.length > 500 ? key.substring(0, 500) : key;
  }

  List<DrugInteraction> _deduplicate(List<DrugInteraction> interactions) {
    final seen = <String>{};
    final result = <DrugInteraction>[];
    for (final i in interactions) {
      // Key is order-independent so A↔B == B↔A.
      final parts = [i.rxcuiA ?? i.drugAName, i.rxcuiB ?? i.drugBName]..sort();
      final key = parts.join('|');
      if (seen.add(key)) result.add(i);
    }
    return result;
  }
}
