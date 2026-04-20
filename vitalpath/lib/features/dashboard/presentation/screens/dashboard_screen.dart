import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/daily_greeting_card.dart';
import '../widgets/step_progress_card.dart';
import '../widgets/timeline_section.dart';

/// The "Health Passbook" Dashboard — the heart of VitalPath.
///
/// Design: Vertical timeline (SRS §7).
/// - Completed tasks → faded state
/// - Upcoming tasks → elevated/active state
/// - Real-time step progress bar (Antigravity responsiveness)
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final stepDataAsync = ref.watch(liveStepDataProvider);
    final todayActivityAsync = ref.watch(todayActivityProvider);
    final activeMedicinesAsync = ref.watch(activeMedicinesProvider);
    final todayMedLogsAsync = ref.watch(todayMedicineLogsProvider);
    final activeMealsAsync = ref.watch(activeMealRoutinesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(liveStepDataProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── App Bar ────────────────────────────────────────
            _DashboardAppBar(
              userProfile: userProfileAsync,
            ),

            // ── Content ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // Greeting card
                  userProfileAsync.when(
                    data: (profile) => DailyGreetingCard(
                      userName: profile?.displayName ?? 'there',
                    ),
                    loading: () => const _ShimmerCard(height: 64),
                    error: (_, __) => const SizedBox.shrink(),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 20),

                  // Step Progress Card (SRS §3.1 — 10,000 steps)
                  stepDataAsync.when(
                    data: (stepData) => StepProgressCard(
                      stepCount: stepData.stepCount,
                      stepGoal: stepData.stepCount > 0
                          ? AppConstants.defaultStepGoal
                          : AppConstants.defaultStepGoal,
                      distanceKm: stepData.distanceKm,
                    ),
                    loading: () => const _ShimmerCard(height: 160),
                    error: (_, __) => StepProgressCard(
                      stepCount: 0,
                      stepGoal: AppConstants.defaultStepGoal,
                      distanceKm: 0,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: 0.1),

                  const SizedBox(height: 24),

                  // Timeline header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Timeline",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, yyyy').format(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  // Medicine Timeline Section
                  activeMedicinesAsync.when(
                    data: (medicines) => todayMedLogsAsync.when(
                      data: (logs) => TimelineSection(
                        title: 'Medications',
                        icon: Icons.medication_rounded,
                        iconColor: AppColors.info,
                        items: medicines
                            .where((m) => m.isActive)
                            .map((med) {
                              final medLogs =
                                  logs.where((l) => l.medicineId == med.id);
                              final isTaken =
                                  medLogs.any((l) => l.action == 'taken');
                              final isSkipped =
                                  medLogs.any((l) => l.action == 'skipped');

                              return TimelineItem(
                                id: med.id,
                                title: med.name,
                                subtitle:
                                    '${med.dosage.toStringAsFixed(med.dosage.truncateToDouble() == med.dosage ? 0 : 1)} ${med.unit}',
                                time: (med.scheduledTimes.isNotEmpty &&
                                        med.scheduledTimes != '[]')
                                    ? med.scheduledTimes
                                        .replaceAll('[', '')
                                        .replaceAll(']', '')
                                        .replaceAll('"', '')
                                        .split(',')
                                        .first
                                        .trim()
                                    : '',
                                status: isTaken
                                    ? TimelineItemStatus.completed
                                    : isSkipped
                                        ? TimelineItemStatus.skipped
                                        : TimelineItemStatus.upcoming,
                                isVerified: med.isVerified,
                                colorHex: med.colorHex,
                              );
                            })
                            .toList(),
                        onAddPressed: () =>
                            context.push(AppConstants.routeMedicineAdd),
                      ),
                      loading: () => const _ShimmerCard(height: 120),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    loading: () => const _ShimmerCard(height: 120),
                    error: (_, __) => const SizedBox.shrink(),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 20),

                  // Meal Timeline Section
                  activeMealsAsync.when(
                    data: (meals) => TimelineSection(
                      title: 'Nutrition',
                      icon: Icons.restaurant_rounded,
                      iconColor: AppColors.accentOrange,
                      items: meals
                          .map((meal) => TimelineItem(
                                id: meal.id,
                                title: meal.mealName,
                                subtitle: '${meal.windowStart} – ${meal.windowEnd}',
                                time: meal.windowStart,
                                status: TimelineItemStatus.upcoming,
                                isVerified: false,
                                colorHex: '#F7A440',
                              ))
                          .toList(),
                      onAddPressed: () =>
                          context.push(AppConstants.routeNutritionAdd),
                    ),
                    loading: () => const _ShimmerCard(height: 100),
                    error: (_, __) => const SizedBox.shrink(),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SliverAppBar ──────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  final AsyncValue<UserProfile?> userProfile;

  const _DashboardAppBar({required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'VitalPath',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        // Sync indicator
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.sync_rounded, color: AppColors.textTertiary),
        ),
        // Profile avatar
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => context.push(AppConstants.routeProfile),
            child: userProfile.when(
              data: (profile) => CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  (profile?.displayName ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              loading: () => const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceAlt,
              ),
              error: (_, __) => const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double height;

  const _ShimmerCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1200.ms,
          color: AppColors.divider,
        );
  }
}
