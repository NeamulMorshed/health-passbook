import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle, AppNotification, Timer;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../providers/insights_provider.dart';
import '../../../models/health_insight.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../models/activity_log.dart';
import '../../../models/patient.dart';
import '../../../models/gamification.dart';
import '../../../models/appointment.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('AI Health Insights')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
            icon: Icons.error_outline_rounded,
            title: "Can't load right now",
            subtitle: 'Check your connection and try again.'),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return _InsightsContent(uid: user.uid);
        },
      ),
    );
  }
}

class _InsightsContent extends ConsumerStatefulWidget {
  final String uid;
  const _InsightsContent({required this.uid});

  @override
  ConsumerState<_InsightsContent> createState() => _InsightsContentState();
}

class _InsightsContentState extends ConsumerState<_InsightsContent> {
  bool _generating = false;

  void _generate({
    required List<Medicine> meds,
    required List<MealLog> meals,
    required List<ActivityLog> activities,
    required PatientProfile? patient,
    required GamificationProfile? gamProfile,
    required List<Appointment> appts,
  }) {
    setState(() => _generating = true);
    ref.read(insightsNotifierProvider.notifier).generate(
      medicines: meds,
      meals: meals,
      activities: activities,
      patient: patient,
      pendingAppointments: appts.where((a) => a.isPending).length,
      medStreak: gamProfile?.medStreak ?? 0,
      activityStreak: gamProfile?.activityStreak ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final insightsState = ref.watch(insightsNotifierProvider);
    final medsAsync = ref.watch(medicinesProvider(widget.uid));
    final mealsAsync = ref.watch(todayMealsProvider(widget.uid));
    final activityAsync = ref.watch(activityLogsProvider(widget.uid));
    final patientAsync = ref.watch(patientProfileProvider(widget.uid));
    final gamAsync = ref.watch(gamificationProvider(widget.uid));
    final apptsAsync = ref.watch(patientAppointmentsProvider((patientId: widget.uid, limit: 50)));

    // Reset _generating when provider stops loading
    ref.listen(insightsNotifierProvider, (_, next) {
      if (!next.isLoading && _generating) setState(() => _generating = false);
    });

    final allLoaded = medsAsync.hasValue && mealsAsync.hasValue && apptsAsync.hasValue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
      children: [
        // Header card — gradient kept
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('Powered by Claude AI', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              const Text(
                'Personalised Health\nInsights',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get AI-powered suggestions based on your medicine adherence, activity, and nutrition data.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (!allLoaded)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Waiting for your health data...',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!allLoaded || insightsState.isLoading || _generating)
                      ? null
                      : () => _generate(
                            meds: medsAsync.asData?.value ?? const <Medicine>[],
                            meals: mealsAsync.asData?.value ?? const <MealLog>[],
                            activities: activityAsync.asData?.value ?? const <ActivityLog>[],
                            patient: patientAsync.asData?.value,
                            gamProfile: gamAsync.asData?.value,
                            appts: apptsAsync.asData?.value ?? const <Appointment>[],
                          ),
                  icon: insightsState.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(insightsState.isLoading ? 'Analysing your data...' : 'Generate Insights', style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Disclaimer — dynamic warning border kept as Container
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoCircle(width: 16, height: 16, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These insights are informational only and not medical advice. Always consult your doctor before making health decisions.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Results
        insightsState.when(
          data: (insights) {
            if (insights.isEmpty) {
              return const EmptyState(
                icon: Icons.lightbulb_outline_rounded,
                title: 'No Insights Yet',
                subtitle: 'Tap "Generate Insights" to get AI-powered health recommendations.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BentoSectionHeader(title: 'Your Insights'),
                const SizedBox(height: 12),
                ...insights.map((insight) => _InsightCard(insight: insight)),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analysing your health data...', style: TextStyle(color: AppColors.mutedForeground)),
              ]),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.error_outline_rounded, color: AppColors.destructive),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to generate insights. Check your connection and try again.', style: TextStyle(fontSize: 13))),
              ]),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _generate(
                  meds: medsAsync.asData?.value ?? const <Medicine>[],
                  meals: mealsAsync.asData?.value ?? const <MealLog>[],
                  activities: activityAsync.asData?.value ?? const <ActivityLog>[],
                  patient: patientAsync.asData?.value,
                  gamProfile: gamAsync.asData?.value,
                  appts: apptsAsync.asData?.value ?? const <Appointment>[],
                ),
                child: const Text('Retry'),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final HealthInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _categoryStyle(insight.category);
    // Dynamic border color — kept as Container
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                insight.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(
                _categoryLabel(insight.category),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(insight.body, style: const TextStyle(fontSize: 13, color: AppColors.foreground, height: 1.4)),
          const SizedBox(height: 10),
          // Dynamic suggestion bg color — kept as Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_rounded, color: color, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(insight.suggestion, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _categoryStyle(String category) {
    switch (category) {
      case 'medication': return (Icons.medication_outlined, AppColors.primary);
      case 'nutrition':  return (Icons.restaurant_rounded, AppColors.warning);
      case 'activity':   return (Icons.directions_walk_rounded, AppColors.success);
      case 'appointments': return (Icons.calendar_month_rounded, AppColors.primary);
      default:           return (Icons.lightbulb_rounded, const Color(0xFF0EA5E9));
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'medication': return 'Medication';
      case 'nutrition':  return 'Nutrition';
      case 'activity':   return 'Activity';
      case 'appointments': return 'Appointments';
      default: return 'General';
    }
  }
}
