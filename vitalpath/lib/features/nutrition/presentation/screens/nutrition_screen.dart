import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// Nutrition & meal routine screen (SRS §4.2).
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(activeMealRoutinesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppConstants.routeNutritionAdd),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return _EmptyNutrition(onAdd: () => context.push(AppConstants.routeNutritionAdd));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: routines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final meal = routines[index];
              return _MealRoutineCard(
                meal: meal,
                animationDelay: (index * 80).ms,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppConstants.routeNutritionAdd),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _MealRoutineCard extends StatelessWidget {
  final MealRoutine meal;
  final Duration animationDelay;

  const _MealRoutineCard({required this.meal, required this.animationDelay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppColors.accentOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${meal.windowStart} – ${meal.windowEnd}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (meal.nutritionalTags != '[]') ...[
                  const SizedBox(height: 6),
                  Text(
                    meal.nutritionalTags
                        .replaceAll('[', '')
                        .replaceAll(']', '')
                        .replaceAll('"', ''),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  // Log meal action
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(60, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('Log'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: animationDelay, duration: 300.ms).slideX(begin: 0.05);
  }
}

class _EmptyNutrition extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyNutrition({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_rounded, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No meal routines yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Set up your daily meal schedule to get\npre-meal reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 52)),
            child: const Text('Add Meal Routine'),
          ),
        ],
      ),
    );
  }
}
