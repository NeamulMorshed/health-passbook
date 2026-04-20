import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/meal_routines_table.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:timezone/timezone.dart' as tz;

/// Add meal routine screen (SRS §4.2).
/// Pre-meal reminders fire 15 minutes before the window start.
class AddMealScreen extends ConsumerStatefulWidget {
  const AddMealScreen({super.key});

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  TimeOfDay _windowStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _windowEnd = const TimeOfDay(hour: 9, minute: 0);
  final List<String> _selectedTags = [];
  bool _isSaving = false;

  static const _nutritionalTags = [
    'Low Sodium',
    'Diabetic Friendly',
    'High Protein',
    'Low Carb',
    'Heart Healthy',
    'Low Fat',
    'Vegetarian',
    'Vegan',
    'Gluten Free',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider)!;
      final db = ref.read(appDatabaseProvider);
      final id = const Uuid().v4();

      final startStr = '${_windowStart.hour.toString().padLeft(2, '0')}:${_windowStart.minute.toString().padLeft(2, '0')}';
      final endStr = '${_windowEnd.hour.toString().padLeft(2, '0')}:${_windowEnd.minute.toString().padLeft(2, '0')}';

      await db.mealRoutineDao.insertRoutine(
        MealRoutinesCompanion.insert(
          id: id,
          userId: user.id,
          mealName: _nameController.text.trim(),
          windowStart: startStr,
          windowEnd: endStr,
          description: Value(_descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim()),
          nutritionalTags: Value(jsonEncode(_selectedTags)),
        ),
      );

      // Schedule pre-meal reminder 15 minutes before window start (SRS §4.2)
      final notifSvc = ref.read(notificationServiceProvider);
      final now = tz.TZDateTime.now(tz.local);
      final preMealTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        _windowStart.hour,
        _windowStart.minute,
      ).subtract(Duration(minutes: AppConstants.preMealReminderMinutes));

      await notifSvc.scheduleMealReminder(
        notificationId: id.hashCode.abs() % 8999,
        mealName: _nameController.text.trim(),
        mealRoutineId: id,
        preMealTime: preMealTime.isBefore(now)
            ? preMealTime.add(const Duration(days: 1))
            : preMealTime,
      );

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Add Meal Routine'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Meal name
            const _Label('Meal Name *'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g., Breakfast, Lunch, Evening Snack',
                prefixIcon: Icon(Icons.restaurant_rounded),
              ),
              validator: Validators.requiredField,
            ),

            const SizedBox(height: 20),

            // Time window
            const _Label('Meal Time Window *'),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'From',
                    time: _windowStart,
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: _windowStart);
                      if (t != null) setState(() => _windowStart = t);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Text('–', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeButton(
                    label: 'To',
                    time: _windowEnd,
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: _windowEnd);
                      if (t != null) setState(() => _windowEnd = t);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Pre-meal reminder note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A reminder will be sent ${AppConstants.preMealReminderMinutes} minutes before the start of your meal window.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Description
            const _Label('Description (optional)'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Any notes about this meal...',
              ),
            ),

            const SizedBox(height: 20),

            // Nutritional tags
            const _Label('Nutritional Tags'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _nutritionalTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (v) {
                    setState(() {
                      if (v) _selectedTags.add(tag);
                      else _selectedTags.remove(tag);
                    });
                  },
                  selectedColor: AppColors.accentOrange.withOpacity(0.15),
                  checkmarkColor: AppColors.accentOrange,
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
