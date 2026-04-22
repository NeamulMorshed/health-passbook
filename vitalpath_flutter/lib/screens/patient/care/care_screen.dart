import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../core/constants/app_constants.dart';

class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});
  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Care'),
            automaticallyImplyLeading: false,
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.mutedForeground,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.medication_rounded), text: 'Medicines'),
                Tab(icon: Icon(Icons.restaurant_rounded), text: 'Food'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _MedicineTab(uid: user.uid),
              _FoodTab(uid: user.uid),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (_tabCtrl.index == 0) {
                _showAddMedicineSheet(context, user.uid);
              } else {
                _showAddMealSheet(context, user.uid);
              }
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(_tabCtrl.index == 0 ? 'Add Medicine' : 'Log Meal', style: const TextStyle(color: Colors.white, fontFamily: 'Inter')),
          ),
        );
      },
    );
  }

  void _showAddMedicineSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddMedicineSheet(uid: uid),
    );
  }

  void _showAddMealSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddMealSheet(uid: uid),
    );
  }
}

// ─── Medicine Tab ──────────────────────────────────────────────────────────────
class _MedicineTab extends ConsumerWidget {
  final String uid;
  const _MedicineTab({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(uid));

    return medsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (meds) {
        if (meds.isEmpty) {
          return EmptyState(
            icon: Icons.medication_outlined,
            title: 'No Medicines Yet',
            subtitle: 'Tap the button below to add your first medicine.',
            actionLabel: 'Add Medicine',
            onAction: () {},
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: meds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _MedCard(med: meds[i], uid: uid),
        );
      },
    );
  }
}

class _MedCard extends ConsumerWidget {
  final Medicine med;
  final String uid;
  const _MedCard({required this.med, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taken = med.takenToday;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: taken ? AppColors.success.withValues(alpha:0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(med.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                Text(med.dosage, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            ),
            if (taken) StatusBadge.success('Taken')
            else StatusBadge.warning('Pending'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _InfoChip(Icons.repeat_rounded, med.frequency),
            const SizedBox(width: 8),
            if (med.prescribedBy != null) _InfoChip(Icons.person_rounded, 'Dr. ${med.prescribedBy}'),
          ]),
          if (!taken) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ref.read(medicineNotifierProvider.notifier).logDose(uid, med.id),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Mark as Taken'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _confirmDelete(context, ref),
                style: OutlinedButton.styleFrom(minimumSize: const Size(40, 40), foregroundColor: AppColors.destructive, side: const BorderSide(color: AppColors.destructive)),
                child: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Medicine', style: TextStyle(fontFamily: 'Inter')),
        content: Text('Remove ${med.name} from your medicines?', style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(medicineNotifierProvider.notifier).delete(uid, med.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.mutedForeground),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
    ]),
  );
}

// ─── Food Tab ──────────────────────────────────────────────────────────────────
class _FoodTab extends ConsumerWidget {
  final String uid;
  const _FoodTab({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider(uid));

    return mealsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (meals) {
        final totalCal = meals.fold(0, (s, m) => s + (m.calories ?? 0));
        return Column(
          children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NutrientStat('Calories', '$totalCal', 'kcal', AppColors.warning),
                  _NutrientStat('Protein', meals.fold(0.0, (s, m) => s + (m.protein ?? 0)).toStringAsFixed(0), 'g', AppColors.primary),
                  _NutrientStat('Carbs', meals.fold(0.0, (s, m) => s + (m.carbs ?? 0)).toStringAsFixed(0), 'g', AppColors.success),
                  _NutrientStat('Fat', meals.fold(0.0, (s, m) => s + (m.fat ?? 0)).toStringAsFixed(0), 'g', AppColors.destructive),
                ],
              ),
            ),
            if (meals.isEmpty)
              Expanded(child: EmptyState(icon: Icons.restaurant_outlined, title: 'No Meals Logged', subtitle: 'Log your first meal for today.'))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: meals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _MealCard(meal: meals[i], uid: uid),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NutrientStat extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _NutrientStat(this.label, this.value, this.unit, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
    Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
  ]);
}

class _MealCard extends ConsumerWidget {
  final MealLog meal;
  final String uid;
  const _MealCard({required this.meal, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealIcons = {
      'Breakfast': Icons.wb_sunny_rounded,
      'Lunch': Icons.light_mode_rounded,
      'Dinner': Icons.nights_stay_rounded,
      'Snack': Icons.cookie_rounded,
    };
    final icon = mealIcons[meal.mealType] ?? Icons.restaurant_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.warning, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(meal.description, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
            StatusBadge.warning(meal.mealType),
          ]),
          const SizedBox(height: 4),
          if (meal.calories != null)
            Text('${meal.calories} kcal', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.mutedForeground),
          onPressed: () => ref.read(mealNotifierProvider.notifier).delete(uid, meal.id),
        ),
      ]),
    );
  }
}

// ─── Add Medicine Sheet ────────────────────────────────────────────────────────
class _AddMedicineSheet extends ConsumerStatefulWidget {
  final String uid;
  const _AddMedicineSheet({required this.uid});
  @override
  ConsumerState<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends ConsumerState<_AddMedicineSheet> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  String _freq = AppConstants.freqOnce;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() { _nameCtrl.dispose(); _dosageCtrl.dispose(); super.dispose(); }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(medicineNotifierProvider.notifier).add(
      widget.uid, name: _nameCtrl.text.trim(), dosage: _dosageCtrl.text.trim(), frequency: _freq,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Add Medicine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              const SizedBox(height: 20),
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Medicine Name', hintText: 'e.g. Metformin'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _dosageCtrl, decoration: const InputDecoration(labelText: 'Dosage', hintText: 'e.g. 500mg'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _freq,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: [AppConstants.freqOnce, AppConstants.freqTwice, AppConstants.freqThrice, AppConstants.freqAsNeeded, AppConstants.freqWeekly]
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontFamily: 'Inter'))))
                    .toList(),
                onChanged: (v) => setState(() => _freq = v!),
              ),
              const SizedBox(height: 20),
              GradientButton(label: 'Add Medicine', onPressed: _save),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Meal Sheet ────────────────────────────────────────────────────────────
class _AddMealSheet extends ConsumerStatefulWidget {
  final String uid;
  const _AddMealSheet({required this.uid});
  @override
  ConsumerState<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<_AddMealSheet> {
  final _descCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  String _type = AppConstants.mealBreakfast;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() { _descCtrl.dispose(); _calCtrl.dispose(); super.dispose(); }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(mealNotifierProvider.notifier).add(
      widget.uid,
      mealType: _type,
      description: _descCtrl.text.trim(),
      calories: int.tryParse(_calCtrl.text),
      protein: double.tryParse(_proteinCtrl.text),
      carbs: double.tryParse(_carbsCtrl.text),
      fat: double.tryParse(_fatCtrl.text),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Log Meal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              const SizedBox(height: 16),
              // Meal type selector
              Row(children: [AppConstants.mealBreakfast, AppConstants.mealLunch, AppConstants.mealDinner, AppConstants.mealSnack].map((t) {
                final sel = _type == t;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.muted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.mutedForeground, fontFamily: 'Inter')),
                  ),
                );
              }).toList()),
              const SizedBox(height: 14),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'What did you eat?', hintText: 'e.g. Rice with vegetables'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _calCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (kcal)'))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _proteinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _carbsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)'))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _fatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat (g)'))),
              ]),
              const SizedBox(height: 20),
              GradientButton(label: 'Log Meal', onPressed: _save),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
