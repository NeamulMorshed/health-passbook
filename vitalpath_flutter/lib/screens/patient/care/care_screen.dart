import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../models/family_member.dart';
import '../../../core/constants/app_constants.dart';
import 'scan_prescription_screen.dart';
import 'add_family_member_screen.dart';

class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});
  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // null = primary user ("Me"), non-null = active family member
  FamilyMember? _activeMember;

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
      error: (_, __) => const Scaffold(body: Center(child: EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'))),
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
            actions: [
              const NotifBell(),
            ],
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
          body: Column(
            children: [
              // Context banner — shown when viewing a family member's data
              if (_activeMember != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    border: const Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.person_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Viewing ${_activeMember!.name}\'s health data',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                            fontFamily: 'Inter'),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _activeMember = null),
                      child: const Text('Switch back',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontFamily: 'Inter')),
                    ),
                  ]),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _MedicineTab(
                      uid: user.uid,
                      activeMember: _activeMember,
                      onSwitcherChanged: (m) => setState(() => _activeMember = m),
                    ),
                    _FoodTab(uid: user.uid),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (_tabCtrl.index == 0) {
                _showMedicineAddChoice(context, user.uid, _activeMember);
              } else {
                _showMealSheet(context, user.uid);
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

  void _showMedicineAddChoice(BuildContext context, String uid, FamilyMember? activeMember) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Add Medicine',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter')),
              const SizedBox(height: 4),
              const Text('How would you like to add a medicine?',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter')),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: AppColors.primary.withValues(alpha: 0.06),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.document_scanner_rounded,
                      color: AppColors.primary, size: 22),
                ),
                title: const Text('Scan Prescription',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter')),
                subtitle: const Text('Take a photo and we\'ll read it for you',
                    style: TextStyle(fontSize: 12, fontFamily: 'Inter')),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.mutedForeground),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanPrescriptionScreen(
                        uid: uid,
                        familyMember: activeMember,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: AppColors.muted,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_rounded,
                      color: AppColors.mutedForeground, size: 22),
                ),
                title: const Text('Add Manually',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter')),
                subtitle: const Text('Enter medicine details yourself',
                    style: TextStyle(fontSize: 12, fontFamily: 'Inter')),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.mutedForeground),
                onTap: () {
                  Navigator.pop(context);
                  _showMedicineSheet(context, uid, activeMember: activeMember);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showMedicineSheet(BuildContext context, String uid,
      {Medicine? existing, FamilyMember? activeMember}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MedicineSheet(
          uid: uid, existing: existing, familyMember: activeMember),
    );
  }

  void _showMealSheet(BuildContext context, String uid, {MealLog? existing}) {
    showLogMealSheet(context, uid, existing: existing);
  }
}

void _confirmDeleteMeal(BuildContext context, WidgetRef ref, String uid, String mealId) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Delete Meal', style: TextStyle(fontFamily: 'Inter')),
      content: const Text('Remove this meal log from today?', style: TextStyle(fontFamily: 'Inter')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogCtx);
            await ref.read(mealNotifierProvider.notifier).delete(uid, mealId);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

void showMedicineSheet(BuildContext context, String uid,
    {Medicine? existing, FamilyMember? familyMember}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) =>
        _MedicineSheet(uid: uid, existing: existing, familyMember: familyMember),
  );
}

void showLogMealSheet(BuildContext context, String uid, {MealLog? existing, String? initialType}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _MealSheet(uid: uid, existing: existing, initialType: initialType),
  );
}

void _showMedDetailSheet(BuildContext context, Medicine med, String uid,
    [FamilyMember? familyMember]) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _MedDetailSheet(med: med, uid: uid, familyMember: familyMember),
  );
}

void _showMealDetailSheet(BuildContext context, MealLog meal, String uid) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _MealDetailSheet(meal: meal, uid: uid),
  );
}

// ─── Medicine Tab ──────────────────────────────────────────────────────────────
class _MedicineTab extends ConsumerWidget {
  final String uid;
  final FamilyMember? activeMember;
  final ValueChanged<FamilyMember?> onSwitcherChanged;

  const _MedicineTab({
    required this.uid,
    required this.activeMember,
    required this.onSwitcherChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider(uid));
    final medsAsync = activeMember == null
        ? ref.watch(medicinesProvider(uid))
        : ref.watch(familyMemberMedicinesProvider(
            (uid: uid, memberId: activeMember!.id)));

    return Column(
      children: [
        // ── Profile Switcher ───────────────────────────────────────────────
        membersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (members) {
            if (members.isEmpty && activeMember == null) {
              return const SizedBox.shrink();
            }
            return Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // "Me" chip
                    _SwitcherChip(
                      label: 'Me',
                      initials: 'Me',
                      isSelected: activeMember == null,
                      onTap: () => onSwitcherChanged(null),
                    ),
                    const SizedBox(width: 8),
                    // Family member chips
                    ...members.map((m) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SwitcherChip(
                            label: m.name.split(' ').first,
                            initials: m.initials,
                            isSelected: activeMember?.id == m.id,
                            photoUrl: m.photoUrl,
                            onTap: () => onSwitcherChanged(m),
                            onLongPress: () => _editMember(context, m),
                          ),
                        )),
                    // Add member chip (only shown when members already exist)
                    if (members.isNotEmpty)
                      _AddMemberChip(
                        onTap: () => _addMember(context),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // ── Medicine list ──────────────────────────────────────────────────
        Expanded(
          child: medsAsync.when(
            loading: () => const _ShimmerCardList(height: 140),
            error: (e, _) =>
                EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
            data: (meds) {
              final memberName = activeMember?.name.split(' ').first;
              if (meds.isEmpty) {
                return EmptyState(
                  icon: Icons.medication_outlined,
                  title: activeMember == null
                      ? 'No Medicines Yet'
                      : 'No Medicines for $memberName',
                  subtitle: 'Tap the button below to add the first medicine.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: meds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _MedCard(
                  med: meds[i],
                  uid: uid,
                  familyMember: activeMember,
                  onTap: () =>
                      _showMedDetailSheet(context, meds[i], uid, activeMember),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addMember(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(uid: uid),
      ),
    );
  }

  void _editMember(BuildContext context, FamilyMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(uid: uid, existing: member),
      ),
    ).then((result) {
      if (result == 'deleted') onSwitcherChanged(null);
    });
  }
}

// ── Switcher chips ─────────────────────────────────────────────────────────────

class _SwitcherChip extends StatelessWidget {
  final String label;
  final String initials;
  final bool isSelected;
  final String? photoUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SwitcherChip({
    required this.label,
    required this.initials,
    required this.isSelected,
    required this.onTap,
    this.photoUrl,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.muted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photoUrl != null)
              CircleAvatar(
                radius: 10,
                backgroundImage: NetworkImage(photoUrl!),
              )
            else
              CircleAvatar(
                radius: 10,
                backgroundColor: isSelected
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppColors.border,
                child: Text(initials,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.foreground,
                        fontFamily: 'Inter')),
              ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.foreground,
                    fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }
}

class _AddMemberChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMemberChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: 14,
                color: AppColors.primary.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text('Add member',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary.withValues(alpha: 0.8),
                    fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }
}

class _MedCard extends ConsumerStatefulWidget {
  final Medicine med;
  final String uid;
  final FamilyMember? familyMember;
  final VoidCallback? onTap;
  const _MedCard({required this.med, required this.uid, this.familyMember, this.onTap});
  @override
  ConsumerState<_MedCard> createState() => _MedCardState();
}

class _MedCardState extends ConsumerState<_MedCard> {
  bool _isTaking = false;

  Future<void> _logDose() async {
    if (_isTaking) return;
    setState(() => _isTaking = true);
    HapticFeedback.mediumImpact();
    try {
      final fm = widget.familyMember;
      if (fm != null) {
        await ref.read(familyMedicinePatchProvider).logDose(widget.uid, fm.id, widget.med.id);
      } else {
        final hp = await ref.read(medicineNotifierProvider.notifier).logDose(widget.uid, widget.med.id);
        if (hp > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('+$hp HP  Dose logged!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.med;
    final uid = widget.uid;
    final familyMember = widget.familyMember;
    final slots = med.todaySlots;
    final fullyTaken = med.fullyTakenToday;
    final hasDue = med.hasDueSlot;
    final hasMissed = med.hasMissedSlot;
    final asNeeded = med.hasNoScheduledTimes;

    // Header badge
    final StatusBadge badge;
    if (fullyTaken) {
      badge = StatusBadge.success('All Taken');
    } else if (hasMissed && !hasDue) {
      badge = StatusBadge.danger('Missed');
    } else if (hasDue) {
      badge = StatusBadge.warning('Due Now');
    } else if (asNeeded && !med.fullyTakenToday) {
      badge = StatusBadge.warning('Pending');
    } else {
      badge = StatusBadge.info('Upcoming');
    }

    // Border colour driven by urgency
    final borderColor = fullyTaken
        ? AppColors.success.withValues(alpha: 0.3)
        : hasMissed
            ? AppColors.warning.withValues(alpha: 0.4)
            : AppColors.border;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(med.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                Text(med.dosage,
                    style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            ),
            badge,
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.mutedForeground),
              onSelected: (v) {
                if (v == 'edit') {
                  showMedicineSheet(context, uid, existing: med, familyMember: familyMember);
                } else {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit', style: TextStyle(fontFamily: 'Inter'))])),
                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.destructive), SizedBox(width: 8), Text('Remove', style: TextStyle(fontFamily: 'Inter', color: AppColors.destructive))])),
              ],
            ),
          ]),

          const SizedBox(height: 10),

          // Info chips
          Wrap(spacing: 8, runSpacing: 6, children: [
            _InfoChip(Icons.repeat_rounded, med.frequency),
            if (med.prescribedBy != null)
              _InfoChip(Icons.person_rounded, 'Dr. ${med.prescribedBy}'),
          ]),

          // ── Slot chips (scheduled medicines) ──────────────────────────────
          if (slots.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.map((slot) => _SlotChip(
                slot: slot,
                onTake: (slot.isDue || slot.isMissed) && !slot.isTaken && !_isTaking
                    ? _logDose
                    : null,
              )).toList(),
            ),
          ],

          // ── Single button for "as needed" medicines ───────────────────────
          if (asNeeded && !fullyTaken) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isTaking ? null : _logDose,
              icon: _isTaking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 16),
              label: const Text('Mark as Taken'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Medicine', style: TextStyle(fontFamily: 'Inter')),
        content: Text('Remove ${widget.med.name} from your medicines?',
            style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (widget.familyMember != null) {
                await ref.read(familyMedicinePatchProvider).delete(widget.uid, widget.familyMember!.id, widget.med.id);
              } else {
                await ref.read(medicineNotifierProvider.notifier).delete(widget.uid, widget.med.id);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Slot Chip ─────────────────────────────────────────────────────────────────

class _SlotChip extends StatelessWidget {
  final DoseSlot slot;
  final VoidCallback? onTake;
  const _SlotChip({required this.slot, this.onTake});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;

    if (slot.isTaken) {
      bg = AppColors.success.withValues(alpha: 0.1);
      fg = AppColors.success;
      icon = Icons.check_circle_rounded;
      label = slot.shortTime;
    } else if (slot.isMissed) {
      bg = AppColors.warning.withValues(alpha: 0.1);
      fg = AppColors.warning;
      icon = Icons.warning_amber_rounded;
      label = 'Missed · ${slot.shortTime}';
    } else if (slot.isDue) {
      bg = AppColors.primary;
      fg = Colors.white;
      icon = Icons.medication_rounded;
      label = 'Take · ${slot.shortTime}';
    } else {
      bg = AppColors.muted;
      fg = AppColors.mutedForeground;
      icon = Icons.schedule_rounded;
      label = slot.shortTime;
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg, fontFamily: 'Inter')),
      ]),
    );

    if (onTake != null) {
      return GestureDetector(onTap: onTake, child: chip);
    }
    return chip;
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
      loading: () => const _ShimmerCardList(height: 74),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (meals) {
        final totalCal = meals.fold(0, (s, m) => s + (m.calories ?? 0));
        return Column(
          children: [
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
              const Expanded(child: EmptyState(icon: Icons.restaurant_outlined, title: 'No Meals Logged', subtitle: 'Log your first meal for today.'))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: meals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _MealCard(
                    meal: meals[i],
                    uid: uid,
                    onTap: () => _showMealDetailSheet(context, meals[i], uid),
                  ),
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
  final VoidCallback? onTap;
  const _MealCard({required this.meal, required this.uid, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealIcons = {
      'Breakfast': Icons.wb_sunny_rounded,
      'Lunch': Icons.light_mode_rounded,
      'Dinner': Icons.nights_stay_rounded,
      'Snack': Icons.cookie_rounded,
    };
    final icon = mealIcons[meal.mealType] ?? Icons.restaurant_rounded;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: AppColors.warning, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(meal.description, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  if (meal.calories != null)
                    Text('${meal.calories} kcal', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                ])),
                StatusBadge.warning(meal.mealType),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.mutedForeground),
                  onSelected: (v) {
                    if (v == 'edit') {
                      showLogMealSheet(context, uid, existing: meal);
                    } else {
                      _confirmDeleteMeal(context, ref, uid, meal.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit', style: TextStyle(fontFamily: 'Inter'))])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.destructive), SizedBox(width: 8), Text('Delete', style: TextStyle(fontFamily: 'Inter', color: AppColors.destructive))])),
                  ],
                ),
              ]),
              if (meal.reminderTime != null) ...[
                const SizedBox(height: 8),
                _InfoChip(Icons.alarm_rounded, '${meal.reminderTime} (${meal.reminderRepeat})'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Medicine Detail Sheet ────────────────────────────────────────────────────

class _MedDetailSheet extends ConsumerWidget {
  final Medicine med;
  final String uid;
  final FamilyMember? familyMember;
  const _MedDetailSheet({required this.med, required this.uid, this.familyMember});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = med.todaySlots;
    final fullyTaken = med.fullyTakenToday;
    final hasDue = med.hasDueSlot;
    final hasMissed = med.hasMissedSlot;

    final StatusBadge badge;
    if (fullyTaken) {
      badge = StatusBadge.success('All Taken');
    } else if (hasMissed && !hasDue) {
      badge = StatusBadge.danger('Missed');
    } else if (hasDue) {
      badge = StatusBadge.warning('Due Now');
    } else if (med.hasNoScheduledTimes && !fullyTaken) {
      badge = StatusBadge.warning('Pending');
    } else {
      badge = StatusBadge.info('Upcoming');
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(med.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                Text(med.dosage, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ])),
              badge,
            ]),

            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),

            // Details grid
            _DetailRow(icon: Icons.repeat_rounded, label: 'Frequency', value: med.frequency),
            if (med.prescribedBy != null)
              _DetailRow(icon: Icons.person_rounded, label: 'Prescribed by', value: 'Dr. ${med.prescribedBy}'),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Start date',
              value: '${med.startDate.day}/${med.startDate.month}/${med.startDate.year}',
            ),
            if (med.endDate != null)
              _DetailRow(
                icon: Icons.event_rounded,
                label: 'End date',
                value: '${med.endDate!.day}/${med.endDate!.month}/${med.endDate!.year}',
              ),
            if (med.reminderTimes.isNotEmpty)
              _DetailRow(
                icon: Icons.autorenew_rounded,
                label: 'Repeat',
                value: med.reminderDays.length == 7
                    ? 'Every day'
                    : med.reminderDays.isEmpty
                        ? 'Daily'
                        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                            .asMap()
                            .entries
                            .where((e) => med.reminderDays.contains(e.key))
                            .map((e) => e.value)
                            .join(', '),
              ),
            if (med.notes != null && med.notes!.isNotEmpty)
              _DetailRow(icon: Icons.notes_rounded, label: 'Notes', value: med.notes!),

            // Today's doses
            if (slots.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("Today's Doses", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              const SizedBox(height: 10),
              ...slots.map((slot) {
                final Color bg;
                final Color fg;
                final IconData icon;
                final String label;
                if (slot.isTaken) {
                  bg = AppColors.success.withValues(alpha: 0.08); fg = AppColors.success;
                  icon = Icons.check_circle_rounded; label = 'Taken';
                } else if (slot.isMissed) {
                  bg = AppColors.warning.withValues(alpha: 0.08); fg = AppColors.warning;
                  icon = Icons.warning_amber_rounded; label = 'Missed';
                } else if (slot.isDue) {
                  bg = AppColors.primary.withValues(alpha: 0.08); fg = AppColors.primary;
                  icon = Icons.alarm_rounded; label = 'Due now';
                } else {
                  bg = AppColors.muted; fg = AppColors.mutedForeground;
                  icon = Icons.schedule_rounded; label = 'Upcoming';
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 10),
                    Text(slot.displayTime, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg, fontFamily: 'Inter')),
                    const Spacer(),
                    Text(label, style: TextStyle(fontSize: 12, color: fg, fontFamily: 'Inter')),
                  ]),
                );
              }),
            ],

            // Dose history summary
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.history_rounded,
              label: 'Total doses logged',
              value: '${med.loggedDoses.length} dose${med.loggedDoses.length == 1 ? '' : 's'}',
            ),

            const SizedBox(height: 28),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showMedicineSheet(context, uid, existing: med, familyMember: familyMember);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit', style: TextStyle(fontFamily: 'Inter')),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ),
              if (med.hasDueSlot || (med.hasNoScheduledTimes && !fullyTaken)) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (familyMember != null) {
                        await ref.read(familyMedicinePatchProvider).logDose(uid, familyMember!.id, med.id);
                      } else {
                        final hp = await ref.read(medicineNotifierProvider.notifier).logDose(uid, med.id);
                        if (hp > 0 && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('+$hp HP  Dose logged!'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Mark as Taken', style: TextStyle(fontFamily: 'Inter')),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Meal Detail Sheet ────────────────────────────────────────────────────────

class _MealDetailSheet extends StatelessWidget {
  final MealLog meal;
  final String uid;
  const _MealDetailSheet({required this.meal, required this.uid});

  @override
  Widget build(BuildContext context) {
    final mealIcons = {
      'Breakfast': Icons.wb_sunny_rounded,
      'Lunch': Icons.light_mode_rounded,
      'Dinner': Icons.nights_stay_rounded,
      'Snack': Icons.cookie_rounded,
    };
    final icon = mealIcons[meal.mealType] ?? Icons.restaurant_rounded;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.warning, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meal.description, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                Text('Logged as ${meal.mealType}', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ])),
              StatusBadge.warning(meal.mealType),
            ]),

            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),

            // Nutrition breakdown
            const Text('Nutrition', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            const SizedBox(height: 12),
            Row(children: [
              _NutritionTile('Calories', meal.calories != null ? '${meal.calories}' : '--', 'kcal', AppColors.warning),
              const SizedBox(width: 10),
              _NutritionTile('Protein', meal.protein != null ? meal.protein!.toStringAsFixed(1) : '--', 'g', AppColors.primary),
              const SizedBox(width: 10),
              _NutritionTile('Carbs', meal.carbs != null ? meal.carbs!.toStringAsFixed(1) : '--', 'g', AppColors.success),
              const SizedBox(width: 10),
              _NutritionTile('Fat', meal.fat != null ? meal.fat!.toStringAsFixed(1) : '--', 'g', AppColors.destructive),
            ]),

            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Other details
            _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Logged at',
              value: '${meal.loggedAt.hour.toString().padLeft(2, '0')}:${meal.loggedAt.minute.toString().padLeft(2, '0')}  •  ${meal.loggedAt.day}/${meal.loggedAt.month}/${meal.loggedAt.year}',
            ),
            if (meal.reminderTime != null)
              _DetailRow(icon: Icons.alarm_rounded, label: 'Reminder', value: '${meal.reminderTime} (${meal.reminderRepeat})'),

            const SizedBox(height: 28),

            // Edit action
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showLogMealSheet(context, uid, existing: meal);
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Meal', style: TextStyle(fontFamily: 'Inter')),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared detail row widget used by both detail sheets
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppColors.mutedForeground),
      const SizedBox(width: 10),
      SizedBox(
        width: 110,
        child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
      ),
    ]),
  );
}

// Nutrition tile for meal detail
class _NutritionTile extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _NutritionTile(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
        Text(unit, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
      ]),
    ),
  );
}

// ─── Medicine Sheet (Add + Edit) ───────────────────────────────────────────────
class _MedicineSheet extends ConsumerStatefulWidget {
  final String uid;
  final Medicine? existing;
  final FamilyMember? familyMember;
  const _MedicineSheet({required this.uid, this.existing, this.familyMember});
  @override
  ConsumerState<_MedicineSheet> createState() => _MedicineSheetState();
}

class _MedicineSheetState extends ConsumerState<_MedicineSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dosageCtrl;
  late String _freq;
  late List<TimeOfDay> _reminderTimes;
  late List<int> _reminderDays;
  final _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final med = widget.existing;
    _nameCtrl = TextEditingController(text: med?.name ?? '');
    _dosageCtrl = TextEditingController(text: med?.dosage ?? '');
    _freq = med?.frequency ?? AppConstants.freqOnce;
    _reminderDays = med?.reminderDays ?? [0, 1, 2, 3, 4, 5, 6];

    if (med != null && med.reminderTimes.isNotEmpty) {
      _reminderTimes = med.reminderTimes.map((s) {
        final parts = s.split(':');
        return TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
      }).toList();
    } else {
      _reminderTimes = _defaultTimesFor(_freq);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _dosageCtrl.dispose(); super.dispose(); }

  int _reminderCountFor(String freq) => switch (freq) {
    AppConstants.freqOnce   => 1,
    AppConstants.freqTwice  => 2,
    AppConstants.freqThrice => 3,
    AppConstants.freqWeekly => 1,
    _                       => 0,
  };

  List<TimeOfDay> _defaultTimesFor(String freq) => switch (freq) {
    AppConstants.freqTwice  => [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)],
    AppConstants.freqThrice => [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 14, minute: 0), const TimeOfDay(hour: 20, minute: 0)],
    _                       => [const TimeOfDay(hour: 8, minute: 0)],
  };

  void _onFreqChanged(String freq) {
    setState(() {
      _freq = freq;
      final count = _reminderCountFor(freq);
      final defaults = _defaultTimesFor(freq);
      _reminderTimes = List.generate(count, (i) => i < _reminderTimes.length ? _reminderTimes[i] : defaults[i < defaults.length ? i : 0]);
    });
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTimes[index]);
    if (picked != null) setState(() => _reminderTimes[index] = picked);
  }

  List<String> get _reminderTimeStrings => _reminderTimes
      .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
      .toList();

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final count = _reminderCountFor(_freq);
    final times = count > 0 ? _reminderTimeStrings.take(count).toList() : <String>[];
    final fm = widget.familyMember;
    final newName = _nameCtrl.text.trim().toLowerCase();

    // Duplicate medicine check — warn before adding (not during edit).
    if (!_isEdit) {
      List<Medicine> existing;
      if (fm != null) {
        existing = ref.read(familyMemberMedicinesProvider((uid: widget.uid, memberId: fm.id))).asData?.value ?? [];
      } else {
        existing = ref.read(medicinesProvider(widget.uid)).asData?.value ?? [];
      }
      final isDuplicate = existing.any((m) => m.name.trim().toLowerCase() == newName);
      if (isDuplicate) {
        final addAnyway = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Duplicate Medicine', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
            content: Text(
              '${_nameCtrl.text.trim()} is already in the medicines list. Add it again?',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Anyway')),
            ],
          ),
        );
        if (addAnyway != true || !mounted) return;
      }
    }

    if (fm != null) {
      // Family member context — use patch provider
      final patch = ref.read(familyMedicinePatchProvider);
      if (_isEdit) {
        await patch.update(widget.uid, fm.id, widget.existing!.id, {
          'name': _nameCtrl.text.trim(),
          'dosage': _dosageCtrl.text.trim(),
          'frequency': _freq,
          'reminderTimes': times,
          'reminderRepeat': 'daily',
          'reminderDays': _reminderDays,
        });
      } else {
        await patch.add(
          widget.uid, fm.id,
          name: _nameCtrl.text.trim(),
          dosage: _dosageCtrl.text.trim(),
          frequency: _freq,
          reminderTimes: times,
          reminderRepeat: 'daily',
          reminderDays: _reminderDays,
        );
      }
    } else {
      // Primary user
      if (_isEdit) {
        await ref.read(medicineNotifierProvider.notifier).update(
          widget.uid, widget.existing!.id,
          name: _nameCtrl.text.trim(), dosage: _dosageCtrl.text.trim(),
          frequency: _freq, reminderTimes: times,
          reminderRepeat: 'daily', reminderDays: _reminderDays,
        );
      } else {
        await ref.read(medicineNotifierProvider.notifier).add(
          widget.uid,
          name: _nameCtrl.text.trim(), dosage: _dosageCtrl.text.trim(),
          frequency: _freq, reminderTimes: times,
          reminderRepeat: 'daily', reminderDays: _reminderDays,
        );
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final count = _reminderCountFor(_freq);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(_isEdit ? 'Edit Medicine' : 'Add Medicine', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                const SizedBox(height: 20),
                TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Medicine Name', hintText: 'e.g. Metformin'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _dosageCtrl, decoration: const InputDecoration(labelText: 'Dosage', hintText: 'e.g. 500mg'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _freq,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: [AppConstants.freqOnce, AppConstants.freqTwice, AppConstants.freqThrice, AppConstants.freqAsNeeded, AppConstants.freqWeekly]
                      .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontFamily: 'Inter'))))
                      .toList(),
                  onChanged: (v) => _onFreqChanged(v!),
                ),
                if (count > 0) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.alarm_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Reminder${count > 1 ? 's' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  ]),
                  const SizedBox(height: 8),
                  ...List.generate(count, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _pickTime(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(count > 1 ? 'Dose ${i + 1}' : 'Reminder time', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                          const Spacer(),
                          Text(_reminderTimes[i].format(context), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Inter')),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                        ]),
                      ),
                    ),
                  )),
                  const SizedBox(height: 12),
                  _DayPickerWidget(
                    selectedDays: _reminderDays,
                    onChanged: (days) => setState(() => _reminderDays = days),
                  ),
                ],
                const SizedBox(height: 20),
                GradientButton(label: _isEdit ? 'Save Changes' : 'Add Medicine', onPressed: _save),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Meal Sheet (Add + Edit) ───────────────────────────────────────────────────
class _MealSheet extends ConsumerStatefulWidget {
  final String uid;
  final MealLog? existing;
  final String? initialType;
  const _MealSheet({required this.uid, this.existing, this.initialType});
  @override
  ConsumerState<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<_MealSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  late String _type;
  late bool _setReminder;
  late TimeOfDay _reminderTime;
  late String _reminderRepeat;
  late List<int> _reminderDays;
  final _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final meal = widget.existing;
    _descCtrl    = TextEditingController(text: meal?.description ?? '');
    _calCtrl     = TextEditingController(text: meal?.calories?.toString() ?? '');
    _proteinCtrl = TextEditingController(text: meal?.protein?.toString() ?? '');
    _carbsCtrl   = TextEditingController(text: meal?.carbs?.toString() ?? '');
    _fatCtrl     = TextEditingController(text: meal?.fat?.toString() ?? '');
    _type = meal?.mealType ?? widget.initialType ?? AppConstants.mealBreakfast;
    _reminderRepeat = meal?.reminderRepeat ?? 'once';
    _reminderDays = meal?.reminderDays ?? [0, 1, 2, 3, 4, 5, 6];
    if (meal?.reminderTime != null) {
      final parts = meal!.reminderTime!.split(':');
      _reminderTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 7, minute: int.tryParse(parts[1]) ?? 30);
      _setReminder = true;
    } else {
      _reminderTime = const TimeOfDay(hour: 7, minute: 30);
      _setReminder = false;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) {
      setState(() => _reminderTime = picked);
      final now = TimeOfDay.now();
      final isPast = picked.hour < now.hour || (picked.hour == now.hour && picked.minute <= now.minute);
      if (isPast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This time has already passed today — the reminder will fire tomorrow.')),
        );
      }
    }
  }

  String get _reminderTimeString =>
      '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final reminderTime = _setReminder ? _reminderTimeString : null;
    final repeat = _setReminder ? _reminderRepeat : 'once';

    final days = _setReminder && repeat == 'daily' ? _reminderDays : <int>[];
    if (_isEdit) {
      await ref.read(mealNotifierProvider.notifier).update(
        widget.uid, widget.existing!.id,
        mealType: _type, description: _descCtrl.text.trim(),
        calories: int.tryParse(_calCtrl.text),
        protein: double.tryParse(_proteinCtrl.text),
        carbs: double.tryParse(_carbsCtrl.text),
        fat: double.tryParse(_fatCtrl.text),
        reminderTime: reminderTime, reminderRepeat: repeat, reminderDays: days,
      );
    } else {
      await ref.read(mealNotifierProvider.notifier).add(
        widget.uid,
        mealType: _type, description: _descCtrl.text.trim(),
        calories: int.tryParse(_calCtrl.text),
        protein: double.tryParse(_proteinCtrl.text),
        carbs: double.tryParse(_carbsCtrl.text),
        fat: double.tryParse(_fatCtrl.text),
        reminderTime: reminderTime, reminderRepeat: repeat, reminderDays: days,
      );
      final hp = await ref.read(gamificationServiceProvider).awardMealLog(widget.uid);
      if (hp > 0 && mounted) showAppSnack(context, '+$hp HP  Meal logged!');
    }
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(_isEdit ? 'Edit Meal' : 'Log Meal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                const SizedBox(height: 16),
                // Meal type selector
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [AppConstants.mealBreakfast, AppConstants.mealLunch, AppConstants.mealDinner, AppConstants.mealSnack].map((t) {
                    final sel = _type == t;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.muted, borderRadius: BorderRadius.circular(8)),
                        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.mutedForeground, fontFamily: 'Inter')),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'What did you eat?', hintText: 'e.g. Rice with vegetables'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
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
                const SizedBox(height: 16),
                // Reminder toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.alarm_rounded, size: 18, color: AppColors.mutedForeground),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Set meal reminder', style: TextStyle(fontSize: 13, fontFamily: 'Inter'))),
                    Switch(value: _setReminder, onChanged: (v) => setState(() => _setReminder = v), activeThumbColor: AppColors.primary),
                  ]),
                ),
                if (_setReminder) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickReminderTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
                      child: Row(children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Text('Remind me at', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                        const Spacer(),
                        Text(_reminderTime.format(context), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Inter')),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Repeat selector
                  Row(children: [
                    const Icon(Icons.repeat_rounded, size: 16, color: AppColors.mutedForeground),
                    const SizedBox(width: 6),
                    const Text('Repeat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    const SizedBox(width: 12),
                    ...[('once', 'Once'), ('daily', 'Recurring')].map(((String, String) opt) {
                      final sel = _reminderRepeat == opt.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _reminderRepeat = opt.$1),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.muted, borderRadius: BorderRadius.circular(8)),
                          child: Text(opt.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.mutedForeground, fontFamily: 'Inter')),
                        ),
                      );
                    }),
                  ]),
                  if (_reminderRepeat == 'daily') ...[
                    const SizedBox(height: 10),
                    _DayPickerWidget(
                      selectedDays: _reminderDays,
                      activeColor: AppColors.success,
                      onChanged: (days) => setState(() => _reminderDays = days),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                GradientButton(label: _isEdit ? 'Save Changes' : 'Log Meal', onPressed: _save),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Day Picker Widget ─────────────────────────────────────────────────────────

class _DayPickerWidget extends StatelessWidget {
  final List<int> selectedDays; // 0=Sun, 1=Mon, …, 6=Sat
  final ValueChanged<List<int>> onChanged;
  final Color activeColor;

  const _DayPickerWidget({
    required this.selectedDays,
    required this.onChanged,
    this.activeColor = AppColors.primary,
  });

  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _fullNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  String get _displayLabel {
    if (selectedDays.length == 7) return 'Every day';
    if (selectedDays.isEmpty) return 'No days selected';
    final sorted = [...selectedDays]..sort();
    return sorted.map((d) => _fullNames[d]).join(', ');
  }

  void _toggle(int day) {
    final next = [...selectedDays];
    if (next.contains(day)) {
      next.remove(day);
    } else {
      next.add(day);
      next.sort();
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                _displayLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selectedDays.isEmpty ? AppColors.mutedForeground : AppColors.foreground,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.mutedForeground),
          ]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final selected = selectedDays.contains(i);
              return GestureDetector(
                onTap: () => _toggle(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? activeColor : Colors.transparent,
                    border: Border.all(
                      color: selected ? activeColor : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.mutedForeground,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer ───────────────────────────────────────────────────────────────────

class _ShimmerCardList extends StatelessWidget {
  final double height;
  const _ShimmerCardList({this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.muted,
      highlightColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
