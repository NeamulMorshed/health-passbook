import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_insight.dart';
import '../core/config/ai_config.dart';

class AiInsightsService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';

  Future<List<HealthInsight>> generateInsights({
    required double medAdherencePct,
    required int avgCalories,
    required int avgSteps,
    required List<String> conditions,
    required String? bloodType,
    required int pendingAppointments,
    required int medStreak,
    required int activityStreak,
  }) async {
    if (kClaudeApiKey == 'YOUR_CLAUDE_API_KEY_HERE') {
      return _mockInsights(medAdherencePct, avgSteps, avgCalories);
    }

    final prompt = _buildPrompt(
      medAdherencePct: medAdherencePct,
      avgCalories: avgCalories,
      avgSteps: avgSteps,
      conditions: conditions,
      bloodType: bloodType,
      pendingAppointments: pendingAppointments,
      medStreak: medStreak,
      activityStreak: activityStreak,
    );

    // A2: Add HTTP timeout to prevent indefinite hanging.
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': kClaudeApiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 1024,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('AI service timed out after 30 seconds');
    }

    if (response.statusCode != 200) {
      throw Exception('AI service error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final contentList = data['content'] as List? ?? [];
    if (contentList.isEmpty) throw Exception('Empty content in AI response');
    final text = contentList.first['text'] as String? ?? '';

    // A3: Robust JSON extraction using last { and last } indices.
    final start = text.lastIndexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) {
      throw Exception('No JSON in response');
    }
    final jsonStr = text.substring(start, end + 1);

    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    final rawInsights = parsed['insights'];
    if (rawInsights == null || rawInsights is! List) {
      throw Exception('Missing or invalid insights array in AI response');
    }
    final insights = rawInsights
        .map((e) => HealthInsight.fromMap(e as Map<String, dynamic>))
        .toList();

    return insights;
  }

  String _buildPrompt({
    required double medAdherencePct,
    required int avgCalories,
    required int avgSteps,
    required List<String> conditions,
    required String? bloodType,
    required int pendingAppointments,
    required int medStreak,
    required int activityStreak,
  }) {
    return '''You are a supportive health assistant for Omra, a personal health app. Analyze the patient's recent health data and provide 3 concise, actionable health insights.

Patient health data (last 7 days):
- Medical conditions: ${conditions.isEmpty ? 'None listed' : conditions.join(', ')}
- Blood type: ${bloodType ?? 'Unknown'}
- Medicine adherence: ${medAdherencePct.toStringAsFixed(0)}%
- Medicine streak: $medStreak consecutive days
- Average daily calories: $avgCalories kcal
- Average daily steps: $avgSteps steps
- Activity streak: $activityStreak consecutive days
- Pending appointments: $pendingAppointments

Respond ONLY with valid JSON in this exact format (no markdown, no extra text):
{
  "insights": [
    {
      "category": "medication",
      "title": "Short title (max 6 words)",
      "body": "One supportive sentence about their health data.",
      "suggestion": "One specific actionable suggestion."
    }
  ]
}

Categories must be one of: medication, nutrition, activity, appointments, general.
Be encouraging, positive, and specific. Do not diagnose or prescribe.''';
  }

  List<HealthInsight> _mockInsights(double adherence, int steps, int calories) {
    return [
      HealthInsight(
        category: 'medication',
        title: adherence >= 80
            ? 'Great Medicine Adherence'
            : 'Improve Medicine Routine',
        body: adherence >= 80
            ? 'You\'ve taken ${adherence.toStringAsFixed(0)}% of your medicines this week — excellent consistency!'
            : 'Your medicine adherence is at ${adherence.toStringAsFixed(0)}% this week. Consistency is key to effectiveness.',
        suggestion: adherence >= 80
            ? 'Keep it up! Consider enabling reminders for any missed medicines.'
            : 'Try setting a daily alarm at a fixed time to build a medicine habit.',
      ),
      HealthInsight(
        category: 'activity',
        title: steps >= 7000 ? 'Active Lifestyle' : 'Boost Your Daily Steps',
        body: steps >= 7000
            ? 'Averaging $steps steps/day puts you in the healthy active range.'
            : 'Your average of $steps steps/day is below the recommended 7,500.',
        suggestion: steps >= 7000
            ? 'Excellent! Try adding a 10-minute brisk walk to reach 10,000 steps.'
            : 'Start with short 5-minute walks after each meal to add ~1,500 steps daily.',
      ),
      HealthInsight(
        category: 'nutrition',
        title: 'Calorie Awareness',
        body:
            'You\'re averaging $calories kcal/day. ${calories > 2500 ? 'That\'s on the higher side for most adults.' : 'Stay mindful of nutritional balance alongside calories.'}',
        suggestion:
            'Log every meal in the Care tab to get a clearer picture of your nutrition patterns.',
      ),
    ];
  }
}
