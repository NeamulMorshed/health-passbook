class PatientAttention {
  final String patientId;
  final String patientName;
  final String? photoUrl;

  /// Adherence over last 7 days (0–100). Null when the patient has no active
  /// medicines with reminder times (can't compute a meaningful rate).
  final double? adherencePct;

  /// Count of abnormal vital readings in the last 7 days.
  final int abnormalVitalsCount;

  /// Human-readable label for the most recent abnormal vital, e.g. "BP 165/95".
  final String? mostRecentAbnormalLabel;

  const PatientAttention({
    required this.patientId,
    required this.patientName,
    this.photoUrl,
    this.adherencePct,
    required this.abnormalVitalsCount,
    this.mostRecentAbnormalLabel,
  });

  /// True when this patient qualifies for the "Needs Attention" section.
  /// Thresholds: adherence < 50% OR any abnormal vital in last 7 days.
  bool get needsAttention =>
      (adherencePct != null && adherencePct! < 50) || abnormalVitalsCount > 0;

  /// Sort key: most severe first.
  /// Lower adherence and more abnormal vitals bubble to the top.
  int compareTo(PatientAttention other) {
    // Patients with both issues first
    final thisIssues = _issueCount;
    final otherIssues = other._issueCount;
    if (otherIssues != thisIssues) return otherIssues.compareTo(thisIssues);
    // Then lowest adherence first
    final thisAdh = adherencePct ?? 100;
    final otherAdh = other.adherencePct ?? 100;
    return thisAdh.compareTo(otherAdh);
  }

  int get _issueCount =>
      ((adherencePct != null && adherencePct! < 50) ? 1 : 0) +
      (abnormalVitalsCount > 0 ? 1 : 0);
}
