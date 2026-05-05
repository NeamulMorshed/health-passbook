import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// RxNorm REST API — free, public, no key required.
// Docs: https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html
class RxNormService {
  RxNormService._();
  static RxNormService? _instance;
  static RxNormService get instance => _instance ??= RxNormService._();

  static const _base = 'https://rxnav.nlm.nih.gov/REST';
  static const _timeout = Duration(seconds: 10);

  final _db = FirebaseFirestore.instance;

  /// Returns the canonical generic (INN/USAN) name for [rawName], or null if
  /// RxNorm has no confident match.
  ///
  /// Results are cached in Firestore (`rxnorm_cache/{key}`) so the same drug
  /// is never looked up twice — including negative results (cached as null).
  Future<String?> lookupGeneric(String rawName) async {
    final key = _cacheKey(rawName);

    // ── 1. Firestore cache hit ──────────────────────────────────────────────
    try {
      final snap = await _db.collection('rxnorm_cache').doc(key).get();
      if (snap.exists) {
        // Null stored → previously confirmed miss; don't re-query.
        return snap.data()?['generic'] as String?;
      }
    } catch (_) {
      // Cache read failed — continue to live lookup.
    }

    // ── 2. RxNorm approximate-term search ──────────────────────────────────
    try {
      final encoded = Uri.encodeComponent(rawName.trim());
      final approxRes = await http
          .get(Uri.parse('$_base/approximateTerm.json?term=$encoded&maxEntries=3'))
          .timeout(_timeout);

      if (approxRes.statusCode != 200) {
        await _cache(key, rawName, null, null);
        return null;
      }

      final approxBody = jsonDecode(approxRes.body) as Map<String, dynamic>;
      final candidates =
          approxBody['approximateGroup']?['candidate'] as List?;

      if (candidates == null || candidates.isEmpty) {
        await _cache(key, rawName, null, null);
        return null;
      }

      // Candidates are already ordered by rank (rank 1 = best match).
      final rxcui = candidates.first['rxcui'] as String?;
      if (rxcui == null) {
        await _cache(key, rawName, null, null);
        return null;
      }

      // ── 3. Resolve to ingredient (IN) ────────────────────────────────────
      final generic = await _resolveToIngredient(rxcui);
      await _cache(key, rawName, generic, rxcui);
      return generic;
    } catch (_) {
      // Network / parse error — fail silently; caller falls back to raw name.
      return null;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Gets the drug name from RxNorm. If the concept is already an Ingredient
  /// (tty=IN / PIN) its name is used directly. Otherwise we follow the
  /// `related` endpoint to find the underlying ingredient.
  Future<String?> _resolveToIngredient(String rxcui) async {
    final propsRes = await http
        .get(Uri.parse('$_base/rxcui/$rxcui/properties.json'))
        .timeout(_timeout);

    if (propsRes.statusCode != 200) return null;

    final props = (jsonDecode(propsRes.body) as Map<String, dynamic>)['properties']
        as Map<String, dynamic>?;
    if (props == null) return null;

    final tty  = props['tty']  as String?;
    final name = props['name'] as String?;

    // IN = Ingredient, PIN = Precise Ingredient — these are the generic names.
    if (tty == 'IN' || tty == 'PIN') return name;

    // Brand name, clinical drug pack, etc. — follow the relationship graph.
    return await _fetchRelatedIngredient(rxcui) ?? name;
  }

  Future<String?> _fetchRelatedIngredient(String rxcui) async {
    final relRes = await http
        .get(Uri.parse('$_base/rxcui/$rxcui/related.json?tty=IN'))
        .timeout(_timeout);

    if (relRes.statusCode != 200) return null;

    final groups = (jsonDecode(relRes.body) as Map<String, dynamic>)['relatedGroup']
            ?['conceptGroup'] as List?;
    if (groups == null) return null;

    for (final g in groups) {
      final conceptProps = g['conceptProperties'] as List?;
      if (conceptProps != null && conceptProps.isNotEmpty) {
        return conceptProps.first['name'] as String?;
      }
    }
    return null;
  }

  Future<void> _cache(
    String key,
    String query,
    String? generic,
    String? rxcui,
  ) async {
    try {
      await _db.collection('rxnorm_cache').doc(key).set({
        'query': query,
        'generic': generic,
        if (rxcui != null) 'rxcui': rxcui,
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Cache write failure is non-fatal.
    }
  }

  /// Normalises [name] to a safe Firestore document ID (max 100 chars).
  String _cacheKey(String name) {
    final key = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return key.length > 100 ? key.substring(0, 100) : key;
  }
}
