// ── Interaction severity ──────────────────────────────────────────────────────

enum InteractionSeverity { major, moderate, minor, unknown }

extension InteractionSeverityX on InteractionSeverity {
  String get label {
    switch (this) {
      case InteractionSeverity.major:    return 'Major';
      case InteractionSeverity.moderate: return 'Moderate';
      case InteractionSeverity.minor:    return 'Minor';
      case InteractionSeverity.unknown:  return 'Interaction';
    }
  }
}

// ── Drug-drug interaction ─────────────────────────────────────────────────────

class DrugInteraction {
  final String drugAName;
  final String drugBName;
  final String? rxcuiA;
  final String? rxcuiB;
  final InteractionSeverity severity;
  final String description;
  final String source; // "DrugBank", "RxNav/NDFRT", etc.

  const DrugInteraction({
    required this.drugAName,
    required this.drugBName,
    this.rxcuiA,
    this.rxcuiB,
    required this.severity,
    required this.description,
    this.source = 'RxNav',
  });

  factory DrugInteraction.fromMap(Map<String, dynamic> m) => DrugInteraction(
        drugAName:   m['drugAName']   as String? ?? '',
        drugBName:   m['drugBName']   as String? ?? '',
        rxcuiA:      m['rxcuiA']      as String?,
        rxcuiB:      m['rxcuiB']      as String?,
        severity:    _severityFrom(m['severity'] as String?),
        description: m['description'] as String? ?? '',
        source:      m['source']      as String? ?? 'RxNav',
      );

  Map<String, dynamic> toMap() => {
        'drugAName':   drugAName,
        'drugBName':   drugBName,
        if (rxcuiA != null) 'rxcuiA': rxcuiA,
        if (rxcuiB != null) 'rxcuiB': rxcuiB,
        'severity':    severity.name,
        'description': description,
        'source':      source,
      };

  static InteractionSeverity _severityFrom(String? s) {
    switch (s) {
      case 'major':    return InteractionSeverity.major;
      case 'moderate': return InteractionSeverity.moderate;
      case 'minor':    return InteractionSeverity.minor;
      default:         return InteractionSeverity.unknown;
    }
  }
}

// ── Dosage warning (DrugBank commercial) ─────────────────────────────────────

class DosageWarning {
  final String drugName;
  final String message;
  final bool isCritical;
  final String? recommendedRange;

  const DosageWarning({
    required this.drugName,
    required this.message,
    this.isCritical = false,
    this.recommendedRange,
  });
}

// ── Contraindication alert (DrugBank commercial) ──────────────────────────────

class ContraindicationAlert {
  final String drugName;
  final String condition;
  final String description;

  /// "absolute" = never use; "relative" = use with caution.
  final String severity;

  const ContraindicationAlert({
    required this.drugName,
    required this.condition,
    required this.description,
    this.severity = 'relative',
  });
}
