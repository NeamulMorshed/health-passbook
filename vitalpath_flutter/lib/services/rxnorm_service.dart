import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// RxNorm REST API — free, public, no key required.
// Docs: https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html
//
// Firestore cache: rxnorm_cache/{normalised_name}
//   Fields: query, generic (String?), rxcui (String?), cachedAt
//
// Both lookupGeneric() and lookupRxcui() share the same cache document and
// write with merge:true so they accumulate fields rather than overwriting each
// other. Each method checks containsKey() before trusting the cached value to
// avoid treating a missing field as a confirmed null.
class RxNormService {
  RxNormService._();
  static RxNormService? _instance;
  static RxNormService get instance => _instance ??= RxNormService._();

  static const _base    = 'https://rxnav.nlm.nih.gov/REST';
  static const _timeout = Duration(seconds: 10);

  final _db = FirebaseFirestore.instance;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the canonical generic (INN/USAN) name for [rawName], or null if
  /// RxNorm has no confident match.
  ///
  /// Caches positive and negative results so the same drug is never looked up
  /// twice. Falls back to null on network or parse error.
  Future<String?> lookupGeneric(String rawName) async {
    final key = _cacheKey(rawName);

    try {
      final snap = await _db.collection('rxnorm_cache').doc(key).get();
      final data = snap.data();
      // Only use cache when 'generic' was explicitly set by a prior lookupGeneric.
      if (snap.exists && data != null && data.containsKey('generic')) {
        return data['generic'] as String?;
      }
    } catch (_) {}

    try {
      final encoded = Uri.encodeComponent(rawName.trim());
      final approxRes = await http
          .get(Uri.parse('$_base/approximateTerm.json?term=$encoded&maxEntries=3'))
          .timeout(_timeout);

      if (approxRes.statusCode != 200) {
        await _merge(key, {'query': rawName, 'generic': null});
        return null;
      }

      final candidates = (jsonDecode(approxRes.body) as Map<String, dynamic>)
          ['approximateGroup']?['candidate'] as List?;

      if (candidates == null || candidates.isEmpty) {
        await _merge(key, {'query': rawName, 'generic': null});
        return null;
      }

      final rxcui = candidates.first['rxcui'] as String?;
      if (rxcui == null) {
        await _merge(key, {'query': rawName, 'generic': null});
        return null;
      }

      final generic = await _resolveToIngredient(rxcui);
      await _merge(key, {
        'query': rawName,
        'generic': generic,
        if (rxcui.isNotEmpty) 'rxcui': rxcui,
      });
      return generic;
    } catch (_) {
      return null;
    }
  }

  /// Returns the RxNorm RxCUI for [rawName], or null if not found.
  ///
  /// Uses a fast direct lookup (`/rxcui.json?search=2`) rather than the
  /// approximateTerm + properties chain. The result is stored in the shared
  /// rxnorm_cache document so subsequent calls for either generic name or rxcui
  /// are served from Firestore.
  Future<String?> lookupRxcui(String rawName) async {
    final key = _cacheKey(rawName);

    try {
      final snap = await _db.collection('rxnorm_cache').doc(key).get();
      final data = snap.data();
      // Only use cache when 'rxcui' was explicitly set by a prior lookup.
      if (snap.exists && data != null && data.containsKey('rxcui')) {
        return data['rxcui'] as String?;
      }
    } catch (_) {}

    try {
      final encoded = Uri.encodeComponent(rawName.trim());
      final res = await http
          .get(Uri.parse('$_base/rxcui.json?name=$encoded&search=2'))
          .timeout(_timeout);

      if (res.statusCode != 200) {
        await _merge(key, {'query': rawName, 'rxcui': null});
        return null;
      }

      final ids = (jsonDecode(res.body) as Map<String, dynamic>)
          ['idGroup']?['rxnormId'] as List?;
      final rxcui = (ids?.isNotEmpty ?? false) ? ids!.first as String? : null;

      await _merge(key, {'query': rawName, 'rxcui': rxcui});
      return rxcui;
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<String?> _resolveToIngredient(String rxcui) async {
    final res = await http
        .get(Uri.parse('$_base/rxcui/$rxcui/properties.json'))
        .timeout(_timeout);
    if (res.statusCode != 200) return null;

    final props = (jsonDecode(res.body) as Map<String, dynamic>)['properties']
        as Map<String, dynamic>?;
    if (props == null) return null;

    final tty  = props['tty']  as String?;
    final name = props['name'] as String?;

    // IN = Ingredient, PIN = Precise Ingredient — these are generic names.
    if (tty == 'IN' || tty == 'PIN') return name;

    return await _fetchRelatedIngredient(rxcui) ?? name;
  }

  Future<String?> _fetchRelatedIngredient(String rxcui) async {
    final res = await http
        .get(Uri.parse('$_base/rxcui/$rxcui/related.json?tty=IN'))
        .timeout(_timeout);
    if (res.statusCode != 200) return null;

    final groups = (jsonDecode(res.body) as Map<String, dynamic>)['relatedGroup']
            ?['conceptGroup'] as List?;
    if (groups == null) return null;

    for (final g in groups) {
      final props = g['conceptProperties'] as List?;
      if (props != null && props.isNotEmpty) {
        return props.first['name'] as String?;
      }
    }
    return null;
  }

  Future<void> _merge(String key, Map<String, dynamic> fields) async {
    try {
      await _db.collection('rxnorm_cache').doc(key).set(
        {...fields, 'cachedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  String _cacheKey(String name) {
    final key = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return key.length > 100 ? key.substring(0, 100) : key;
  }
}
