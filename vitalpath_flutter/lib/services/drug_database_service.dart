import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class DrugEntry {
  final String id;
  final String generic;
  final String category;
  final List<String> brands;
  final List<String> dosageForms;
  final String defaultFrequency;

  const DrugEntry({
    required this.id,
    required this.generic,
    required this.category,
    required this.brands,
    required this.dosageForms,
    required this.defaultFrequency,
  });

  factory DrugEntry.fromMap(Map<String, dynamic> m) => DrugEntry(
        id: m['id'] as String,
        generic: m['generic'] as String,
        category: m['category'] as String,
        brands: List<String>.from(m['brands'] as List),
        dosageForms: List<String>.from(m['dosageForms'] as List),
        defaultFrequency: m['defaultFrequency'] as String,
      );
}

class DrugMatch {
  final DrugEntry drug;
  final double confidence;
  final String matchedTerm;

  const DrugMatch({
    required this.drug,
    required this.confidence,
    required this.matchedTerm,
  });
}

class DrugDatabaseService {
  DrugDatabaseService._();
  static DrugDatabaseService? _instance;
  static DrugDatabaseService get instance =>
      _instance ??= DrugDatabaseService._();

  List<DrugEntry> _drugs = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/bangladesh_drugs.json');
    final list = jsonDecode(raw) as List;
    _drugs = list.map((e) => DrugEntry.fromMap(e as Map<String, dynamic>)).toList();
    _loaded = true;
  }

  /// Returns the best fuzzy match for [input] above [threshold] (0.0–1.0).
  /// Searches both generic names and brand names.
  /// Returns null if no match exceeds threshold.
  DrugMatch? findBestMatch(String input, {double threshold = 0.80}) {
    if (!_loaded || _drugs.isEmpty || input.trim().isEmpty) return null;

    final query = input.trim().toLowerCase();
    DrugMatch? best;

    for (final drug in _drugs) {
      // Check generic name
      final genScore = _similarity(query, drug.generic.toLowerCase());
      if (genScore > (best?.confidence ?? threshold - 0.001)) {
        best = DrugMatch(drug: drug, confidence: genScore, matchedTerm: drug.generic);
      }

      // Check each brand name
      for (final brand in drug.brands) {
        final brandScore = _similarity(query, brand.toLowerCase());
        if (brandScore > (best?.confidence ?? threshold - 0.001)) {
          best = DrugMatch(drug: drug, confidence: brandScore, matchedTerm: brand);
        }
      }
    }

    if (best == null || best.confidence < threshold) return null;
    return best;
  }

  /// Returns the canonical display name: "Generic (Brand)" if a brand was the
  /// matched term and differs from the generic, otherwise just the generic.
  String canonicalName(DrugMatch match) {
    final g = match.drug.generic;
    final t = match.matchedTerm;
    if (t.toLowerCase() == g.toLowerCase()) return g;
    return '$g ($t)';
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - _levenshtein(a, b) / maxLen;
  }

  int _levenshtein(String a, String b) {
    final la = a.length, lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;

    // Single flat array, previous row then current row.
    final prev = List<int>.generate(lb + 1, (i) => i);
    final curr = List<int>.filled(lb + 1, 0);

    for (var i = 1; i <= la; i++) {
      curr[0] = i;
      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = min(
          min(prev[j] + 1, curr[j - 1] + 1),
          prev[j - 1] + cost,
        );
      }
      prev.setAll(0, curr);
    }
    return prev[lb];
  }
}
