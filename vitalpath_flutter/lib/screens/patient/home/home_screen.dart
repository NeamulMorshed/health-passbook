import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
// import '../../../providers/gamification_provider.dart';
import '../../../models/app_user.dart';
import '../../../models/family_member.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../core/constants/app_constants.dart';
import '../care/care_screen.dart';
import '../../../providers/vitals_provider.dart';
import '../../../models/vital_reading.dart';
import '../../../core/widgets/onboarding_tour.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: EmptyState(icon: Icons.wifi_off_rounded, title: 'Can\'t connect right now', subtitle: 'Check your internet connection and pull to refresh.'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        if (user.userType == UserType.caregiver) {
          return _CaregiverHomeContent(user: user);
        }
        // Show first-run tour once after onboarding completes.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (context.mounted) maybeShowOnboardingTour(context); },
        );
        return _HomeContent(user: user);
      },
    );
  }
}

// ── Notification permission nudge ─────────────────────────────────────────────
class _NotifPermBanner extends ConsumerStatefulWidget {
  const _NotifPermBanner();
  @override
  ConsumerState<_NotifPermBanner> createState() => _NotifPermBannerState();
}

class _NotifPermBannerState extends ConsumerState<_NotifPermBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final permAsync = ref.watch(notifPermGrantedProvider);
    // Only show when we know permission is denied (not while loading).
    final granted = permAsync.asData?.value ?? true;
    if (granted) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notifications off', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.foreground)),
                const SizedBox(height: 2),
                const Text('Enable notifications to receive medicine reminders.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedForeground)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    await openAppSettings();
                    // Refresh permission check when user returns from settings.
                    ref.invalidate(notifPermGrantedProvider);
                  },
                  child: const Text('Open Settings', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.mutedForeground),
            onPressed: () => setState(() => _dismissed = true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
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
    final apptsAsync = ref.watch(patientAppointmentsProvider((patientId: user.uid, limit: 50)));
    final vitalsAsync = ref.watch(vitalsProvider(user.uid));
    final pendingAppts = apptsAsync.asData?.value.where((a) => a.isPending).length ?? 0;

    final greeting = _greeting();
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            Text(
              user.name.isNotEmpty ? user.name : 'Patient',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(today, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ),
          ),
        ),
        actions: const [NotifBell()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(medicinesProvider(user.uid));
          ref.invalidate(todayMealsProvider(user.uid));
          ref.invalidate(activityLogsProvider(user.uid));
          ref.invalidate(patientAppointmentsProvider((patientId: user.uid, limit: 50)));
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _NotifPermBanner(),
                  // AI Insights shortcut — prominent placement above stats
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
                  const SizedBox(height: 10),

                  // Vitals shortcut banner
                  _VitalsBanner(vitalsAsync: vitalsAsync, uid: user.uid),
                  const SizedBox(height: 14),

                  // Family status bar (shown when family members exist)
                  _FamilyStatusBar(uid: user.uid),

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
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.75,
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
                              return StatCard(label: 'Steps', value: '$steps', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success, onTap: () => context.push('/activity'));
                            },
                            loading: () => const StatCard(label: 'Steps', value: '--', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success),
                            error: (_, __) => const StatCard(label: 'Steps', value: '--', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success),
                          ),
                          StatCard(label: 'Appointments', value: '$pendingAppts', unit: 'pending', icon: Icons.calendar_today_rounded, color: AppColors.doctorPrimary, onTap: () => context.go('/appointments')),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(height: 28),

                  // Upcoming Tasks
                  _UpcomingTasksCard(uid: user.uid),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
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

// ── Family Status Bar ─────────────────────────────────────────────────────────
// Shows a horizontal scroll of compact avatar chips for each family member.
// Renders nothing when empty or loading.

class _FamilyStatusBar extends ConsumerWidget {
  final String uid;
  const _FamilyStatusBar({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider(uid));

    return membersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Household Status',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                  fontFamily: 'Inter'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _FamilyStatusChip(
                  uid: uid,
                  member: members[i],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FamilyStatusChip extends ConsumerWidget {
  final String uid;
  final FamilyMember member;
  const _FamilyStatusChip({required this.uid, required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(
        familyMemberMedicinesProvider((uid: uid, memberId: member.id)));

    final Color dotColor = _statusColor(medsAsync);

    return GestureDetector(
      onTap: () => context.go('/care'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: member.photoUrl != null
                      ? NetworkImage(member.photoUrl!)
                      : null,
                  child: member.photoUrl == null
                      ? Text(
                          member.initials,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'Inter'),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 52,
              child: Text(
                member.name.split(' ').first,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                    fontFamily: 'Inter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AsyncValue<List<Medicine>> medsAsync) {
    final meds = medsAsync.asData?.value;
    if (meds == null) return AppColors.mutedForeground;

    final activeMeds = meds.where((m) => m.isActive).toList();
    if (activeMeds.isEmpty) return AppColors.mutedForeground; // grey — no medicines

    // Red: any missed slot, no due slot
    final anyMissed = activeMeds.any((m) => m.hasMissedSlot && !m.hasDueSlot);
    if (anyMissed) return AppColors.destructive;

    // Amber: some due
    final anyDue = activeMeds.any((m) => m.hasDueSlot);
    if (anyDue) return AppColors.warning;

    // Green: all taken today
    final allTaken = activeMeds.every((m) => m.takenToday);
    if (allTaken) return AppColors.success;

    return AppColors.mutedForeground; // grey fallback
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

    final dueMeds = meds.where((m) {
      if (!m.isActive) return false;
      return m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot;
    }).toList();

    final missedMeds = meds.where((m) {
      if (!m.isActive) return false;
      return m.hasMissedSlot && !m.hasDueSlot;
    }).toList();

    final upcomingMeals = _upcomingMeals(meals);
    final totalPending = dueMeds.length + upcomingMeals.length;

    if (medsAsync.isLoading || mealsAsync.isLoading) {
      return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
    }

    final header = Row(children: [
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
    ]);

    if (totalPending == 0 && missedMeds.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(children: [
            Icon(Icons.celebration_rounded, size: 32, color: AppColors.success),
            SizedBox(height: 8),
            Text("You're all caught up!",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            SizedBox(height: 2),
            Text('Great job keeping up with your health today.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ]),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header,
      const SizedBox(height: 12),

      // Due medicines
      ...dueMeds.take(3).map((m) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _TaskMedCard(medicine: m, uid: widget.uid),
      )),
      if (dueMeds.length > 3)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => context.go('/care'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text('+${dueMeds.length - 3} more — see all in Care',
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ),

      // Missed medicines
      ...missedMeds.take(2).map((m) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _TaskMedCard(medicine: m, uid: widget.uid, isMissed: true),
      )),

      // Upcoming meals
      ...upcomingMeals.map((mealType) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _TaskMealCard(
          mealType: mealType,
          uid: widget.uid,
          onTap: () => showLogMealSheet(context, widget.uid, initialType: mealType),
        ),
      )),
    ]);
  }

  List<String> _upcomingMeals(List<MealLog> logged) {
    final loggedTypes = logged.map((m) => m.mealType).toSet();
    final h = DateTime.now().hour;
    return [
      if (h < 14 && !loggedTypes.contains(AppConstants.mealBreakfast)) AppConstants.mealBreakfast,
      if (h < 18 && !loggedTypes.contains(AppConstants.mealLunch)) AppConstants.mealLunch,
      if (h < 23 && !loggedTypes.contains(AppConstants.mealDinner)) AppConstants.mealDinner,
    ];
  }
}

// ── Caregiver Home Content ────────────────────────────────────────────────────
class _CaregiverHomeContent extends ConsumerStatefulWidget {
  final AppUser user;
  const _CaregiverHomeContent({required this.user});
  @override
  ConsumerState<_CaregiverHomeContent> createState() =>
      _CaregiverHomeContentState();
}

class _CaregiverHomeContentState extends ConsumerState<_CaregiverHomeContent> {
  String? _selectedMemberId;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider(widget.user.uid));
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return membersAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
          body: Center(
              child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Something went wrong',
                  subtitle: 'Pull to refresh or try again.'))),
      data: (members) {
        // Auto-select the first member if none selected yet.
        if (_selectedMemberId == null && members.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedMemberId = members.first.id));
        }

        final selectedMember = members
            .where((m) => m.id == _selectedMemberId)
            .firstOrNull;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.surface,
            surfaceTintColor: AppColors.surface,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter')),
                Text(
                  widget.user.name.isNotEmpty
                      ? widget.user.name
                      : 'Caregiver',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: AppColors.foreground),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(today,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                          fontFamily: 'Inter')),
                ),
              ),
            ),
            actions: const [NotifBell()],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(familyMembersProvider(widget.user.uid));
              if (_selectedMemberId != null) {
                ref.invalidate(familyMemberMedicinesProvider(
                    (uid: widget.user.uid, memberId: _selectedMemberId!)));
              }
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Who are you checking on? ──────────────────────────
                      const Text(
                        'Who are you checking on today?',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                            fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 10),
                      if (members.isEmpty)
                        _EmptyMembersCard(caregiverUid: widget.user.uid)
                      else
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: members.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final m = members[i];
                              final selected = m.id == _selectedMemberId;
                              return GestureDetector(
                                onTap: () => setState(
                                    () => _selectedMemberId = m.id),
                                child: Column(children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.15),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFFF59E0B)
                                            : AppColors.border,
                                        width: selected ? 2.5 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        m.initials,
                                        style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFFF59E0B)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      m.name.split(' ').first,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Inter',
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: selected
                                            ? const Color(0xFFF59E0B)
                                            : AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),

                      // ── Selected member's content ─────────────────────────
                      if (selectedMember != null) ...[
                        Row(children: [
                          Container(
                            width: 6,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "${selectedMember.name}'s Overview",
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                                color: AppColors.foreground),
                          ),
                          if (selectedMember.age != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${selectedMember.age} yrs · ${selectedMember.relationship}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                  fontFamily: 'Inter'),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 16),
                        _CaregiverMedSection(
                          caregiverUid: widget.user.uid,
                          memberId: selectedMember.id,
                          memberName: selectedMember.name,
                        ),
                        const SizedBox(height: 20),
                        _CaregiverQuickActions(
                          caregiverUid: widget.user.uid,
                          memberId: selectedMember.id,
                        ),
                      ] else if (members.isNotEmpty) ...[
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Empty members placeholder ─────────────────────────────────────────────────
class _EmptyMembersCard extends StatelessWidget {
  final String caregiverUid;
  const _EmptyMembersCard({required this.caregiverUid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        const Icon(Icons.family_restroom_rounded,
            size: 36, color: Color(0xFFF59E0B)),
        const SizedBox(height: 10),
        const Text('No family members yet',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: AppColors.foreground)),
        const SizedBox(height: 4),
        const Text('Go to the Care tab to add the people you care for.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
                fontFamily: 'Inter')),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () => context.go('/care'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFF59E0B)),
            foregroundColor: const Color(0xFFF59E0B),
          ),
          child: const Text('Go to Care',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Medicine section for the selected family member ───────────────────────────
class _CaregiverMedSection extends ConsumerWidget {
  final String caregiverUid;
  final String memberId;
  final String memberName;
  const _CaregiverMedSection(
      {required this.caregiverUid,
      required this.memberId,
      required this.memberName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(familyMemberMedicinesProvider(
        (uid: caregiverUid, memberId: memberId)));

    return medsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
      data: (meds) {
        final activeMeds = meds.where((m) => m.isActive).toList();
        final takenToday = activeMeds.where((m) => m.takenToday).length;
        final dueMeds =
            activeMeds.where((m) => m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Summary stat row
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.medication_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    '$takenToday/${activeMeds.length}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'Inter'),
                  ),
                  const Text('taken today',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                          fontFamily: 'Inter')),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: dueMeds.isNotEmpty
                      ? AppColors.warning.withValues(alpha: 0.07)
                      : AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: dueMeds.isNotEmpty
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(
                      dueMeds.isNotEmpty
                          ? Icons.alarm_rounded
                          : Icons.check_circle_rounded,
                      color: dueMeds.isNotEmpty
                          ? AppColors.warning
                          : AppColors.success,
                      size: 20),
                  const SizedBox(height: 6),
                  Text(
                    '${dueMeds.length}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: dueMeds.isNotEmpty
                            ? AppColors.warning
                            : AppColors.success,
                        fontFamily: 'Inter'),
                  ),
                  Text(
                    dueMeds.isNotEmpty ? 'due now' : 'all done',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter'),
                  ),
                ]),
              ),
            ),
          ]),

          if (activeMeds.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                const Icon(Icons.medication_outlined,
                    size: 28, color: AppColors.mutedForeground),
                const SizedBox(height: 8),
                Text('No medicines for $memberName yet',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter')),
                const SizedBox(height: 4),
                const Text('Add from the Care tab.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter')),
              ]),
            ),
          ] else if (dueMeds.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Due now',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                    fontFamily: 'Inter')),
            const SizedBox(height: 8),
            ...dueMeds.take(3).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CaregiverMedTile(
                    medicine: m,
                    caregiverUid: caregiverUid,
                    memberId: memberId,
                  ),
                )),
            if (dueMeds.length > 3)
              GestureDetector(
                onTap: () => context.go('/care'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                        '+${dueMeds.length - 3} more — see all in Care',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: const Column(children: [
                Icon(Icons.celebration_rounded,
                    size: 28, color: AppColors.success),
                SizedBox(height: 6),
                Text('All medicines taken!',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: AppColors.success)),
              ]),
            ),
          ],
        ]);
      },
    );
  }
}

// ── Single medicine tile for caregiver view ───────────────────────────────────
class _CaregiverMedTile extends ConsumerWidget {
  final Medicine medicine;
  final String caregiverUid;
  final String memberId;
  const _CaregiverMedTile(
      {required this.medicine,
      required this.caregiverUid,
      required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = medicine.nextPendingSlot;
    final subtitle = slot != null
        ? '${medicine.dosage} · Due at ${slot.displayTime}'
        : '${medicine.dosage} · ${medicine.frequency}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(medicine.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter')),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter')),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              await ref
                  .read(familyMedicinePatchProvider)
                  .logDose(caregiverUid, memberId, medicine.id);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Give',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter')),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Caregiver quick actions ───────────────────────────────────────────────────
class _CaregiverQuickActions extends StatelessWidget {
  final String caregiverUid;
  final String memberId;
  const _CaregiverQuickActions(
      {required this.caregiverUid, required this.memberId});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              color: AppColors.foreground)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _ActionBtn(
            icon: Icons.medication_rounded,
            label: 'Add Medicine',
            color: AppColors.primary,
            onTap: () => context.go('/care'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            icon: Icons.calendar_month_rounded,
            label: 'Appointments',
            color: const Color(0xFFF59E0B),
            onTap: () => context.go('/appointments'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            icon: Icons.person_add_rounded,
            label: 'Add Member',
            color: AppColors.success,
            onTap: () => context.go('/care'),
          ),
        ),
      ]),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFamily: 'Inter')),
        ]),
      ),
    );
  }
}

// ── Vitals Banner ─────────────────────────────────────────────────────────────
class _VitalsBanner extends StatelessWidget {
  final AsyncValue<List<VitalReading>> vitalsAsync;
  final String uid;
  const _VitalsBanner({required this.vitalsAsync, required this.uid});

  @override
  Widget build(BuildContext context) {
    final readings = vitalsAsync.asData?.value ?? [];
    final latestBpSys =
        readings.where((r) => r.type == VitalType.bpSystolic).firstOrNull;
    final latestBpDia =
        readings.where((r) => r.type == VitalType.bpDiastolic).firstOrNull;
    final latestPulse =
        readings.where((r) => r.type == VitalType.pulse).firstOrNull;

    String bpLabel = 'No readings yet';
    String pulseLabel = '';

    if (latestBpSys != null && latestBpDia != null) {
      bpLabel =
          'BP: ${latestBpSys.value.toInt()}/${latestBpDia.value.toInt()} mmHg';
    } else if (latestBpSys != null) {
      bpLabel = 'BP Sys: ${latestBpSys.value.toInt()} mmHg';
    }

    if (latestPulse != null) {
      pulseLabel = '  ·  Pulse: ${latestPulse.value.toInt()} bpm';
    }

    return GestureDetector(
      onTap: () => context.push('/vitals'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.monitor_heart_rounded,
                color: AppColors.destructive, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Vitals',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter')),
              Text(
                bpLabel + pulseLabel,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.mutedForeground),
        ]),
      ),
    );
  }
}

// ── Task Med Card (Care page style) ───────────────────────────────────────────
class _TaskMedCard extends ConsumerWidget {
  final Medicine medicine;
  final String uid;
  final bool isMissed;
  const _TaskMedCard({required this.medicine, required this.uid, this.isMissed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = isMissed
        ? medicine.todaySlots.where((s) => s.isMissed).firstOrNull
        : medicine.nextPendingSlot;

    final String subtitle;
    if (slot != null) {
      subtitle = isMissed
          ? 'Missed · ${slot.displayTime}'
          : '${medicine.dosage} · Due at ${slot.displayTime}';
    } else {
      subtitle = '${medicine.dosage} · ${medicine.frequency}';
    }

    final totalSlots = medicine.todaySlots.length;
    final takenSlots = medicine.todaySlots.where((s) => s.isTaken).length;

    final iconColor  = isMissed ? AppColors.warning : AppColors.primary;
    final btnColor   = isMissed ? AppColors.warning : AppColors.primary;
    final borderColor = isMissed
        ? AppColors.warning.withValues(alpha: 0.35)
        : AppColors.border;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.medication_rounded, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(medicine.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                ),
                if (totalSlots > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(6)),
                    child: Text('$takenSlots/$totalSlots',
                        style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: isMissed ? AppColors.warning : AppColors.mutedForeground,
                      fontFamily: 'Inter')),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              final hp = await ref.read(medicineNotifierProvider.notifier).logDose(uid, medicine.id);
              if (hp > 0 && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('+$hp HP  Dose logged!'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: btnColor, borderRadius: BorderRadius.circular(10)),
              child: Text(isMissed ? 'Log' : 'Take',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Task Meal Card — reads preferred time from SharedPreferences ───────────────
class _TaskMealCard extends StatefulWidget {
  final String mealType;
  final String uid;
  final VoidCallback onTap;
  const _TaskMealCard({required this.mealType, required this.uid, required this.onTap});
  @override
  State<_TaskMealCard> createState() => _TaskMealCardState();
}

class _TaskMealCardState extends State<_TaskMealCard> {
  static const _defaults = {
    'Breakfast': '7:30 AM',
    'Lunch': '12:30 PM',
    'Dinner': '7:00 PM',
  };
  String? _timeHint;

  @override
  void initState() {
    super.initState();
    _loadTime();
  }

  Future<void> _loadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'meal_time_${widget.mealType.toLowerCase()}';
    final saved = prefs.getString(key);
    if (mounted) setState(() => _timeHint = saved ?? _defaults[widget.mealType]);
  }

  @override
  Widget build(BuildContext context) {
    const mealIcons = {
      'Breakfast': Icons.wb_sunny_rounded,
      'Lunch': Icons.light_mode_rounded,
      'Dinner': Icons.nights_stay_rounded,
      'Snack': Icons.cookie_rounded,
    };
    final icon = mealIcons[widget.mealType] ?? Icons.restaurant_rounded;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Log your ${widget.mealType}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                Text(
                  _timeHint != null ? 'Usual time · $_timeHint' : "Haven't logged this meal yet",
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter'),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
                child: const Text('Log Meal',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
