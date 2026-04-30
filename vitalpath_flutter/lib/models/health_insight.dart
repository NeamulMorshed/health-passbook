class HealthInsight {
  final String category;
  final String title;
  final String body;
  final String suggestion;

  const HealthInsight({
    required this.category,
    required this.title,
    required this.body,
    required this.suggestion,
  });

  factory HealthInsight.fromMap(Map<String, dynamic> map) {
    return HealthInsight(
      category: map['category']?.toString() ?? 'general',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      suggestion: map['suggestion']?.toString() ?? '',
    );
  }
}
