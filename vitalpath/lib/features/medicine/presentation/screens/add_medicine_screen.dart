import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/medicine_entity.dart';
import '../providers/medicine_provider.dart';

/// Add / Edit Medicine screen (SRS §4.1).
/// Implements all SRS validation rules:
/// - End date cannot precede start date
/// - Dosage must be positive numeric
/// - Inventory tracking with refill threshold
class AddMedicineScreen extends ConsumerStatefulWidget {
  final MedicineEntity? existingMedicine;

  const AddMedicineScreen({super.key, this.existingMedicine});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _inventoryController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedUnit = 'pills';
  String _selectedFrequency = 'daily';
  List<TimeOfDay> _scheduledTimes = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String _colorHex = '#0B6E4F';
  int _refillThreshold = 5;

  static const _unitOptions = ['pills', 'tablet', 'capsule', 'mg', 'ml', 'drops', 'puff'];
  static const _frequencyOptions = [
    ('daily', 'Daily', 1),
    ('twice_daily', 'Twice Daily', 2),
    ('thrice_daily', 'Three Times Daily', 3),
    ('weekly', 'Weekly', 1),
    ('as_needed', 'As Needed', 0),
  ];

  static const _colorOptions = [
    '#0B6E4F', '#60A5FA', '#34D399', '#FBBF24',
    '#F87171', '#A78BFA', '#F472B6', '#FB923C',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingMedicine != null) {
      _populateForm(widget.existingMedicine!);
    }
  }

  void _populateForm(MedicineEntity med) {
    _nameController.text = med.name;
    _dosageController.text = med.dosage.toString();
    _inventoryController.text = med.inventoryCount.toString();
    _notesController.text = med.notes ?? '';
    _selectedUnit = med.unit;
    _selectedFrequency = med.frequency;
    _startDate = med.startDate;
    _endDate = med.endDate;
    _colorHex = med.colorHex;
    _scheduledTimes = med.scheduledTimes.map((t) {
      final parts = t.split(':');
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _inventoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final times = _scheduledTimes
        .map((t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList();

    try {
      await ref.read(medicineFormNotifierProvider.notifier).save(
            name: _nameController.text.trim(),
            dosage: double.parse(_dosageController.text),
            unit: _selectedUnit,
            frequency: _selectedFrequency,
            scheduledTimes: times,
            startDate: _startDate,
            endDate: _endDate,
            inventoryCount: int.tryParse(_inventoryController.text) ?? 0,
            refillThreshold: _refillThreshold,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            colorHex: _colorHex,
            existingId: widget.existingMedicine?.id,
          );

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingMedicine != null;
    final isLoading =
        ref.watch(medicineFormNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine' : 'Add Medicine'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _save,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Color picker ──────────────────────────────────
            _SectionTitle(title: 'Color'),
            const SizedBox(height: 8),
            Row(
              children: _colorOptions.map((hex) {
                final color = _hexToColor(hex);
                final isSelected = _colorHex == hex;
                return GestureDetector(
                  onTap: () => setState(() => _colorHex = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Medicine Name ─────────────────────────────────
            _SectionTitle(title: 'Medicine Name *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g., Metformin, Lisinopril',
                prefixIcon: Icon(Icons.medication_rounded),
              ),
              validator: Validators.requiredField,
            ),

            const SizedBox(height: 20),

            // ── Dosage + Unit ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Dosage *'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dosageController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '500'),
                        validator: (v) => Validators.positiveNumber(v, fieldName: 'Dosage'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Unit *'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(),
                        items: _unitOptions
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedUnit = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Frequency ─────────────────────────────────────
            _SectionTitle(title: 'Frequency *'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _frequencyOptions.map((opt) {
                final isSelected = _selectedFrequency == opt.$1;
                return ChoiceChip(
                  label: Text(opt.$2),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFrequency = opt.$1;
                        // Auto-set scheduled times based on frequency
                        if (opt.$3 == 2) {
                          _scheduledTimes = [
                            const TimeOfDay(hour: 8, minute: 0),
                            const TimeOfDay(hour: 20, minute: 0),
                          ];
                        } else if (opt.$3 == 3) {
                          _scheduledTimes = [
                            const TimeOfDay(hour: 8, minute: 0),
                            const TimeOfDay(hour: 14, minute: 0),
                            const TimeOfDay(hour: 20, minute: 0),
                          ];
                        } else if (opt.$3 == 1) {
                          _scheduledTimes = [
                            const TimeOfDay(hour: 8, minute: 0),
                          ];
                        }
                      });
                    }
                  },
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Scheduled Times ───────────────────────────────
            if (_selectedFrequency != 'as_needed') ...[
              _SectionTitle(title: 'Reminder Times'),
              const SizedBox(height: 8),
              ..._scheduledTimes.asMap().entries.map((entry) {
                return _TimeSelector(
                  time: entry.value,
                  onChanged: (time) {
                    setState(() => _scheduledTimes[entry.key] = time);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],

            // ── Start & End Date ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Start Date *'),
                      const SizedBox(height: 8),
                      _DateButton(
                        date: _startDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'End Date'),
                      const SizedBox(height: 8),
                      _DateButton(
                        date: _endDate,
                        placeholder: 'Ongoing',
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _endDate ?? _startDate.add(const Duration(days: 30)),
                            firstDate: _startDate,
                            lastDate: DateTime(2030),
                          );
                          setState(() => _endDate = picked);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Inventory ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Inventory Count'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _inventoryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(hintText: '30'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Refill Alert At'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _refillThreshold,
                        decoration: const InputDecoration(),
                        items: [3, 5, 7, 10, 14]
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('$n left'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _refillThreshold = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Notes ─────────────────────────────────────────
            _SectionTitle(title: 'Instructions / Notes'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Take with food, avoid grapefruit',
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final TimeOfDay time;
  final void Function(TimeOfDay) onChanged;

  const _TimeSelector({required this.time, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final DateTime? date;
  final String? placeholder;
  final VoidCallback onTap;

  const _DateButton({
    required this.onTap,
    this.date,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? DateFormat('MMM d, yyyy').format(date!)
                  : (placeholder ?? 'Select'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: date != null
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
