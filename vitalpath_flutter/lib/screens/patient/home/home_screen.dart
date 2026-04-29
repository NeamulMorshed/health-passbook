import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
// import '../../../providers/gamification_provider.dart';
import '../../../models/app_user.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../core/constants/app_constants.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return _HomeContent(user: user);
      },
    );
  }
}

class _HomeContent extends ConsumerWidget {
  final AppUser user;
  const _HomeContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(user.uid));
    final mealsAsync = ref.watch(todayMealsProvider(user.uid));
    final activityAsync = ref.watch(activityLogsProvider(user.uid));
    final notifsAsync = ref.watch(notificationsProvider(user.uid));
    final apptsAsync = ref.watch(patientAppointmentsProvider((patientId: user.uid, limit: 50)));
    // final gamAsync = ref.watch(gamificationProvider(user.uid));
    final unreadCount = notifsAsync.asData?.value.where((n) => !n.isRead).length ?? 0;
    final pendingAppts = apptsAsync.asData?.value.where((a) => a.isPending).length ?? 0;
    // final gamProfile = gamAsync.asData?.value;
    // final bestStreak = [gamProfile?.medStreak ?? 0, gamProfile?.mealStreak ?? 0, gamProfile?.activityStreak ?? 0].reduce((a, b) => a > b ? a : b);

    final greeting = _greeting();
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(medicinesProvider(user.uid)),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                            const SizedBox(height: 2),
                            Text(user.name.isNotEmpty ? user.name : 'Patient', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
                            const SizedBox(height: 2),
                            Text(today, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                          ],
                        ),
                      ),
                      // // Streak badge
                      // if (bestStreak > 0)
                      //   GestureDetector(
                      //     onTap: () => context.push('/gamification'),
                      //     child: Container(
                      //       margin: const EdgeInsets.only(right: 8),
                      //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      //       decoration: BoxDecoration(
                      //         color: AppColors.warning.withValues(alpha: 0.12),
                      //         borderRadius: BorderRadius.circular(22),
                      //         border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      //       ),
                      //       child: Row(mainAxisSize: MainAxisSize.min, children: [
                      //         const Text('🔥', style: TextStyle(fontSize: 14)),
                      //         const SizedBox(width: 4),
                      //         Text('$bestStreak', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning, fontFamily: 'Inter')),
                      //       ]),
                      //     ),
                      //   ),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_outlined, color: AppColors.foreground, size: 22),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: 0, right: 0,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                      unreadCount > 9 ? '9+' : '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Health Stats
                    const SectionHeader(title: 'Today\'s Overview'),
                    const SizedBox(height: 12),
                    medsAsync.when(
                      data: (meds) {
                        final taken = meds.where((m) => m.takenToday).length;
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            StatCard(label: 'Medicines', value: '$taken/${meds.length}', unit: 'taken', icon: Icons.medication_rounded, color: AppColors.primary, onTap: () => context.go('/care')),
                            mealsAsync.when(
                              data: (meals) {
                                final cal = meals.fold(0, (sum, m) => sum + (m.calories ?? 0));
                                return StatCard(label: 'Calories', value: '$cal', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: AppColors.warning, onTap: () => context.go('/care'));
                              },
                              loading: () => const StatCard(label: 'Calories', value: '--', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: AppColors.warning),
                              error: (_, __) => const StatCard(label: 'Calories', value: '--', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: AppColors.warning),
                            ),
                            activityAsync.when(
                              data: (logs) {
                                final todayLogs = logs.where((l) {
                                  final now = DateTime.now();
                                  return l.loggedAt.day == now.day && l.loggedAt.month == now.month;
                                }).toList();
                                final steps = todayLogs.fold(0, (s, l) => s + (l.steps ?? 0));
                                return StatCard(label: 'Steps', value: '$steps', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success, onTap: () => context.go('/activity'));
                              },
                              loading: () => const StatCard(label: 'Steps', value: '--', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success),
                              error: (_, __) => const StatCard(label: 'Steps', value: '--', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success),
                            ),
                            StatCard(label: 'Appointments', value: '$pendingAppts', unit: 'pending', icon: Icons.calendar_today_rounded, color: AppColors.doctorPrimary, onTap: () => context.push('/appointments')),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 28),

                    // Upcoming Tasks
                    _UpcomingTasksCard(uid: user.uid),
                    const SizedBox(height: 28),


                    // // Gamification level shortcut
                    // GestureDetector(
                    //   onTap: () => context.push('/gamification'),
                    //   child: Container(
                    //     padding: const EdgeInsets.all(16),
                    //     decoration: BoxDecoration(
                    //       color: AppColors.surface,
                    //       borderRadius: BorderRadius.circular(14),
                    //       border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    //     ),
                    //     child: Row(children: [
                    //       Container(
                    //         padding: const EdgeInsets.all(10),
                    //         decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    //         child: const Icon(Icons.military_tech_rounded, color: AppColors.primary, size: 24),
                    //       ),
                    //       const SizedBox(width: 14),
                    //       Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    //         Text(
                    //           gamProfile != null ? 'Level ${gamProfile.level} • ${gamProfile.levelTitle}' : 'Health Rewards',
                    //           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                    //         ),
                    //         Text(
                    //           gamProfile != null ? '${gamProfile.hp} HP • ${gamProfile.hpToNextLevel} to next level' : 'Earn HP by logging health data',
                    //           style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter'),
                    //         ),
                    //       ])),
                    //       const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.mutedForeground),
                    //     ]),
                    //   ),
                    // ),
                    // const SizedBox(height: 14),

                    // AI Insights shortcut
                    GestureDetector(
                      onTap: () => context.push('/insights'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF0EA5E9).withValues(alpha: 0.85), const Color(0xFF6366F1).withValues(alpha: 0.85)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(children: [
                          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
                          SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('AI Health Insights', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                            Text('Get personalised suggestions from Claude AI', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                          ])),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ── Upcoming Tasks Card ────────────────────────────────────────────────────────
// Uses a 1-minute ticker so slot windows re-evaluate automatically as time
// passes — medicines reappear in the card when the next slot window opens.

class _UpcomingTasksCard extends ConsumerStatefulWidget {
  final String uid;
  const _UpcomingTasksCard({required this.uid});
  @override
  ConsumerState<_UpcomingTasksCard> createState() => _UpcomingTasksCardState();
}

class _UpcomingTasksCardState extends ConsumerState<_UpcomingTasksCard> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medsAsync = ref.watch(medicinesProvider(widget.uid));
    final mealsAsync = ref.watch(todayMealsProvider(widget.uid));

    final meds = medsAsync.asData?.value ?? [];
    final meals = mealsAsync.asData?.value ?? [];

    // Medicines with a currently-due slot that is not yet taken.
    // "As needed" (no reminderTimes) appear if not taken at all today.
    final dueMeds = meds.where((m) {
      if (!m.isActive) return false;
      return m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot;
    }).toList();

    // Medicines where every due slot passed without a dose — shown separately.
    final missedMeds = meds.where((m) {
      if (!m.isActive) return false;
      return m.hasMissedSlot && !m.hasDueSlot;
    }).toList();

    final suggestedMeal = _suggestMeal(meals);
    final totalPending = dueMeds.length + (suggestedMeal != null ? 1 : 0);

    if (medsAsync.isLoading || mealsAsync.isLoading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              const Icon(Icons.checklist_rounded, size: 18, color: AppColors.foreground),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Today's Tasks",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
              if (totalPending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$totalPending left',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Inter')),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, size: 12, color: AppColors.success),
                    SizedBox(width: 4),
                    Text('All done',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success, fontFamily: 'Inter')),
                  ]),
                ),
            ]),
          ),

          // All-done celebration
          if (totalPending == 0 && missedMeds.isEmpty) ...[
            Divider(height: 1, color: AppColors.border),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(children: [
                Icon(Icons.celebration_rounded, size: 32, color: AppColors.success),
                SizedBox(height: 8),
                Text("You're all caught up!",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                SizedBox(height: 2),
                Text('Great job keeping up with your health today.',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            ),
          ] else ...[
            // Due medicines
            if (dueMeds.isNotEmpty) ...[
              Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Row(children: [
                  const Icon(Icons.medication_rounded, size: 13, color: AppColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    '${dueMeds.length} medicine${dueMeds.length == 1 ? '' : 's'} due now',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.mutedForeground, fontFamily: 'Inter'),
                  ),
                ]),
              ),
              ...dueMeds.take(3).map((m) => _MedTaskRow(medicine: m, uid: widget.uid)),
              if (dueMeds.length > 3)
                InkWell(
                  onTap: () => context.go('/care'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: Text('+${dueMeds.length - 3} more — see all',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                  ),
                ),
            ],

            // Missed medicines (secondary, muted)
            if (missedMeds.isNotEmpty) ...[
              Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text('${missedMeds.length} missed — log late dose',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.warning, fontFamily: 'Inter')),
                ]),
              ),
              ...missedMeds.take(2).map((m) => _MedTaskRow(medicine: m, uid: widget.uid, isMissed: true)),
            ],

            // Meal task
            if (suggestedMeal != null) ...[
              Divider(height: 1, color: AppColors.border),
              _MealTaskRow(mealType: suggestedMeal, onTap: () => context.go('/care')),
            ],
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String? _suggestMeal(List<MealLog> logged) {
    final loggedTypes = logged.map((m) => m.mealType).toSet();
    final h = DateTime.now().hour;
    if (h < 11 && !loggedTypes.contains(AppConstants.mealBreakfast)) return AppConstants.mealBreakfast;
    if (h < 15 && !loggedTypes.contains(AppConstants.mealLunch)) return AppConstants.mealLunch;
    if (h < 21 && !loggedTypes.contains(AppConstants.mealDinner)) return AppConstants.mealDinner;
    return null;
  }
}

class _MedTaskRow extends ConsumerWidget {
  final Medicine medicine;
  final String uid;
  final bool isMissed;
  const _MedTaskRow({required this.medicine, required this.uid, this.isMissed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pick the relevant slot for the subtitle label
    final slot = isMissed
        ? medicine.todaySlots.where((s) => s.isMissed).firstOrNull
        : medicine.nextPendingSlot;

    final String subtitle;
    if (slot != null) {
      subtitle = isMissed
          ? 'Missed · ${slot.displayTime} — tap to log late dose'
          : '${medicine.dosage} · Due at ${slot.displayTime}';
    } else {
      subtitle = '${medicine.dosage} · ${medicine.frequency}';
    }

    // Show remaining slots count when there are multiple
    final totalSlots = medicine.todaySlots.length;
    final takenSlots = medicine.todaySlots.where((s) => s.isTaken).length;
    final showProgress = totalSlots > 1;

    final iconColor = isMissed ? AppColors.warning : AppColors.primary;
    final btnColor  = isMissed ? AppColors.warning : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.medication_rounded, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(medicine.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
              if (showProgress)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.muted, borderRadius: BorderRadius.circular(6)),
                  child: Text('$takenSlots/$totalSlots doses',
                      style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                ),
            ]),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: isMissed ? AppColors.warning : AppColors.mutedForeground, fontFamily: 'Inter')),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            await ref.read(medicineNotifierProvider.notifier).logDose(uid, medicine.id);
            // final hp = await ref.read(gamificationServiceProvider).awardMedicineDose(uid);
            // if (hp > 0 && context.mounted) {
            //   showAppSnack(context, '+$hp HP  ${isMissed ? 'Late dose logged!' : 'Medicine taken!'}');
            // }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: btnColor, borderRadius: BorderRadius.circular(9)),
            child: Text(isMissed ? 'Log' : 'Take',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          ),
        ),
      ]),
    );
  }
}

class _MealTaskRow extends StatelessWidget {
  final String mealType;
  final VoidCallback onTap;
  const _MealTaskRow({required this.mealType, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.restaurant_rounded, color: AppColors.success, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Log your $mealType', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          const Text("Haven't logged this meal yet", style: TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(9)),
            child: const Text('Log Meal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          ),
        ),
      ]),
    );
  }
}
