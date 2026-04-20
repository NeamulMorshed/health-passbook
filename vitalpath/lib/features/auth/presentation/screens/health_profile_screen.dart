import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/user_profile_table.dart';
import '../../../../core/services/health_connector_service.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Health profile completion screen — final step of onboarding (SRS §3.1).
/// Collects: Height, Weight, Condition, then requests Health Connect permissions.
class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  ConsumerState<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _nameController = TextEditingController();

  final List<String> _selectedConditions = [];
  bool _isSaving = false;

  static const _commonConditions = [
    'Type 2 Diabetes',
    'Hypertension',
    'Heart Disease',
    'Asthma',
    'Arthritis',
    'Thyroid',
    'High Cholesterol',
    'Chronic Kidney Disease',
    'COPD',
    'None',
  ];

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider)!;
      final db = ref.read(appDatabaseProvider);

      // Validate weight (SRS §5.1 — improbable value check)
      final weight = double.parse(_weightController.text);
      if (weight > AppConstants.maxReasonableWeightKg) {
        _showWeightWarning();
        setState(() => _isSaving = false);
        return;
      }

      final height = double.parse(_heightController.text);

      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: user.id,
          phoneNumber: user.phone ?? '',
          displayName: Value(_nameController.text.trim()),
          heightCm: Value(height),
          weightKg: Value(weight),
          conditions: Value(_selectedConditions.join(',')),
          onboardingCompleted: const Value(true),
        ),
      );

      // Request Health Connect permissions
      await _requestHealthPermissions();

      if (mounted) {
        context.go(AppConstants.routeDashboard);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _requestHealthPermissions() async {
    final healthConnector = ref.read(healthConnectorServiceProvider);
    await healthConnector.requestPermissions();
  }

  void _showWeightWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please double-check your weight entry for accuracy.'),
        backgroundColor: AppColors.warning,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            children: [
              const SizedBox(height: 48),

              // Header
              const Text(
                'Your Health\nProfile',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 8),
              const Text(
                'This helps us personalize your experience. All data is encrypted and private.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 36),

              // Name field
              _SectionLabel(label: 'Your Name'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g., John Smith',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: Validators.requiredField,
              ),

              const SizedBox(height: 20),

              // Height & Weight
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Height (cm)'),
                        TextFormField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(hintText: '170'),
                          validator: (v) => Validators.numericRange(
                            v,
                            min: AppConstants.minReasonableHeightCm,
                            max: AppConstants.maxReasonableHeightCm,
                            fieldName: 'Height',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Weight (kg)'),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(hintText: '70'),
                          validator: (v) => Validators.numericRange(
                            v,
                            min: AppConstants.minReasonableWeightKg,
                            max: AppConstants.maxReasonableWeightKg,
                            fieldName: 'Weight',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Conditions
              _SectionLabel(label: 'Health Conditions (select all that apply)'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonConditions.map((condition) {
                  final isSelected = _selectedConditions.contains(condition);
                  return FilterChip(
                    label: Text(condition),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (condition == 'None') _selectedConditions.clear();
                          _selectedConditions.add(condition);
                        } else {
                          _selectedConditions.remove(condition);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 48),

              // Health Connect permission note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Next, we\'ll ask permission to read your step count from Android Health Connect.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Complete Setup'),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
