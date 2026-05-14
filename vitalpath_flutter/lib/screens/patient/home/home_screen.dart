import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../models/app_user.dart';
import '../../../models/family_member.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../models/appointment.dart';
import '../../../core/constants/app_constants.dart';
import '../care/care_screen.dart';
import '../../../providers/vitals_provider.dart';
import '../../../core/widgets/onboarding_tour.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../models/caregiver_connection.dart';
import '../../caregiver/accept_invite_screen.dart';
import '../../caregiver/caregiver_patient_profile_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
          body: Center(
              child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Can\'t connect right now',
                  subtitle: 'Check your internet connection and pull to refresh.'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (context.mounted) context.go('/user-select'); });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (user.userType == UserType.caregiver) {
          return _CaregiverHomeContent(user: user);
        }
        WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) maybeShowOnboardingTour(context); });
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
    final granted = ref.watch(notifPermGrantedProvider).asData?.value ?? true;
    if (granted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        color: AppColors.warningLight,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          HugeIcon(icon: HugeIcons.strokeRoundedAlertDiamond, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Notifications off',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              const Text('Enable to receive medicine reminders.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  await openAppSettings();
                  ref.invalidate(notifPermGrantedProvider);
                },
                child: const Text('Open Settings',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary, decoration: TextDecoration.underline)),
              ),
            ]),
          ),
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: AppColors.textTertiary, size: 16),
            onPressed: () => setState(() => _dismissed = true),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.zero,
          ),
        ]),
      ),
    );
  }
}

// ── Pending caregiver invite banner ──────────────────────────────────────────
class _PendingInviteBanner extends ConsumerWidget {
  final String email;
  const _PendingInviteBanner({required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (email.isEmpty) return const SizedBox.shrink();
    final invites = ref.watch(pendingInvitesForEmailProvider(email)).asData?.value ?? [];
    if (invites.isEmpty) return const SizedBox.shrink();

    return Column(
      children: invites.map((inv) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: BentoCard(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AcceptInviteScreen(connection: inv))),
          child: Row(children: [
            HugeIcon(icon: HugeIcons.strokeRoundedShield01, color: const Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${inv.patientName} invited you to their Care Circle',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                const Text('Tap to view and accept or decline',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              ]),
            ),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: const Color(0xFF7C3AED), size: 16),
          ]),
        ),
      )).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Patient Home Screen
// ══════════════════════════════════════════════════════════════════════════════
class _HomeContent extends ConsumerWidget {
  final AppUser user;
  const _HomeContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(user.uid));
    final mealsAsync = ref.watch(todayMealsProvider(user.uid));
    ref.watch(activityLogsProvider(user.uid));
    final apptsAsync = ref.watch(patientAppointmentsProvider((patientId: user.uid, limit: 50)));
    ref.watch(vitalsProvider(user.uid));
    final gamAsync = ref.watch(gamificationProvider(user.uid));
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_greeting(), style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 1),
            Text(
              user.name.isNotEmpty ? user.name : 'Patient',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.foreground),
            ),
          ],
        ),
        actions: const [NotifBell()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(medicinesProvider(user.uid));
          ref.invalidate(todayMealsProvider(user.uid));
          ref.invalidate(activityLogsProvider(user.uid));
          ref.invalidate(patientAppointmentsProvider((patientId: user.uid, limit: 50)));
          ref.invalidate(vitalsProvider(user.uid));
          ref.invalidate(gamificationProvider(user.uid));
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── AWARENESS CARD ────────────────────────────────────────
                  _DailyAwarenessCard(uid: user.uid),

                  // ── SNAPSHOT ──────────────────────────────────────────────
                  _DailySnapshotRow(
                    medsAsync: medsAsync,
                    medStreak: gamAsync.asData?.value.medStreak,
                    apptsAsync: apptsAsync,
                  ),
                  const SizedBox(height: 12),

                  // ── ALERTS ────────────────────────────────────────────────
                  const _NotifPermBanner(),
                  _PendingInviteBanner(email: user.email ?? ''),

                  // ── TODAY'S ACTIONS ───────────────────────────────────────
                  _UpcomingTasksCard(uid: user.uid),
                  const SizedBox(height: 12),

                  // ── DAILY STATUS ──────────────────────────────────────────
                  _CaregiversActiveBanner(uid: user.uid),
                  const SizedBox(height: 12),

                  // ── CONTEXT ───────────────────────────────────────────────
                  _TimeContextualCard(uid: user.uid, medsAsync: medsAsync, mealsAsync: mealsAsync),
                  const SizedBox(height: 12),
                  _RefillCountdownCard(medsAsync: medsAsync),

                  // ── NUMBERS ───────────────────────────────────────────────
                  const SizedBox(height: 12),
                  _AdherenceRingCard(uid: user.uid),
                  const SizedBox(height: 12),
                  _FamilyStatusBar(uid: user.uid),

                  // ── AI INSIGHTS ───────────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/insights'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF0EA5E9).withValues(alpha: 0.85), const Color(0xFF6366F1).withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedSparkles, color: Colors.white, size: 24),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('AI Health Insights', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Personalised suggestions from Claude AI', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ])),
                        HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.white70, size: 14),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
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
    if (h >= 5 && h < 12) return 'Good Morning';
    if (h >= 12 && h < 17) return 'Good Afternoon';
    if (h >= 17 && h < 23) return 'Good Evening';
    return 'Good Night';
  }
}

// ── TIER 3: Caregiver active banner ──────────────────────────────────────────
class _CaregiversActiveBanner extends ConsumerWidget {
  final String uid;
  const _CaregiversActiveBanner({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(patientCaregiverConnectionsProvider(uid)).asData?.value ?? [];
    final connected = connections.where((c) => c.status == 'connected').toList();
    if (connected.isEmpty) return const SizedBox.shrink();

    final names = connected.map((c) => c.caregiverName?.split(' ').first ?? c.caregiverEmail).take(2).join(' & ');
    final verb = connected.length == 1 ? 'is' : 'are';

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(children: [
        HugeIcon(icon: HugeIcons.strokeRoundedShield01, color: const Color(0xFF7C3AED), size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text('$names $verb in your care circle',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        ),
        GestureDetector(
          onTap: () => context.push('/care-circle'),
          child: const Text('Manage', style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── TIER 4: Time-contextual card ──────────────────────────────────────────────
class _TimeContextualCard extends StatelessWidget {
  final String uid;
  final AsyncValue<List<Medicine>> medsAsync;
  final AsyncValue<List<MealLog>> mealsAsync;
  const _TimeContextualCard({required this.uid, required this.medsAsync, required this.mealsAsync});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final meds = medsAsync.asData?.value ?? [];
    final meals = mealsAsync.asData?.value ?? [];
    final loggedTypes = meals.map((m) => m.mealType).toSet();

    if (h >= 5 && h < 11) {
      final dueMeds = meds.where((m) => m.isActive && m.hasDueSlot).toList();
      return _ContextCard(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedSun01, color: const Color(0xFFF59E0B), size: 18),
        color: const Color(0xFFF59E0B),
        heading: 'Morning routine',
        actionLabel: dueMeds.isNotEmpty ? 'View Medicines' : 'Log Breakfast',
        body: dueMeds.isNotEmpty ? 'You have ${dueMeds.length} medicine${dueMeds.length == 1 ? '' : 's'} to take this morning.' : loggedTypes.contains(AppConstants.mealBreakfast) ? 'Breakfast done! Morning medicines all taken.' : 'Start your day — take your medicines and log breakfast.',
        onAction: () => dueMeds.isNotEmpty ? context.go('/care') : showLogMealSheet(context, uid, initialType: AppConstants.mealBreakfast),
      );
    } else if (h >= 11 && h < 14) {
      return _ContextCard(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedSun01, color: AppColors.primary, size: 18),
        color: AppColors.primary,
        heading: 'Midday check-in',
        actionLabel: loggedTypes.contains(AppConstants.mealLunch) ? 'Log Vitals' : 'Log Lunch',
        body: loggedTypes.contains(AppConstants.mealLunch) ? 'Lunch logged! A good time to check your blood pressure.' : 'Lunchtime — logging meals helps track your daily nutrition.',
        onAction: () => loggedTypes.contains(AppConstants.mealLunch) ? context.go('/vitals') : showLogMealSheet(context, uid, initialType: AppConstants.mealLunch),
      );
    } else if (h >= 14 && h < 17) {
      return _ContextCard(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedRunningShoes, color: AppColors.success, size: 18),
        color: AppColors.success,
        heading: 'Afternoon boost',
        actionLabel: 'Log Activity',
        body: 'Good time for a walk or light activity. Logging steps keeps you on track.',
        onAction: () => context.push('/activity'),
      );
    } else if (h >= 17 && h < 21) {
      final eveningDue = meds.where((m) => m.isActive && m.hasDueSlot).toList();
      return _ContextCard(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedMoon, color: const Color(0xFF7C3AED), size: 18),
        color: const Color(0xFF7C3AED),
        heading: 'Evening routine',
        actionLabel: eveningDue.isNotEmpty ? 'View Medicines' : 'Log Dinner',
        body: eveningDue.isNotEmpty ? '${eveningDue.length} evening medicine${eveningDue.length == 1 ? '' : 's'} still due.' : loggedTypes.contains(AppConstants.mealDinner) ? 'Evening all done — great health day!' : 'Log dinner to complete your daily record.',
        onAction: () => eveningDue.isNotEmpty ? context.go('/care') : showLogMealSheet(context, uid, initialType: AppConstants.mealDinner),
      );
    } else {
      final allDone = meds.where((m) => m.isActive).every((m) => m.takenToday);
      return _ContextCard(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedBed, color: AppColors.mutedForeground, size: 18),
        color: AppColors.mutedForeground,
        heading: 'End of day',
        body: allDone ? 'All medicines taken today — excellent health day!' : 'Check your medicines before bed to complete today\'s log.',
        actionLabel: 'View Summary',
        onAction: () => context.go('/care'),
      );
    }
  }
}

class _ContextCard extends StatelessWidget {
  final Widget icon;
  final Color color;
  final String heading, body, actionLabel;
  final VoidCallback onAction;
  const _ContextCard({required this.icon, required this.color, required this.heading, required this.body, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      color: color.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Center(child: icon),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(heading, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.foreground, height: 1.4)),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                minimumSize: const Size(0, 36),
              ),
              child: Text(actionLabel),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ── TIER 4: Refill countdown ──────────────────────────────────────────────────
class _RefillCountdownCard extends StatelessWidget {
  final AsyncValue<List<Medicine>> medsAsync;
  const _RefillCountdownCard({required this.medsAsync});

  @override
  Widget build(BuildContext context) {
    final meds = medsAsync.asData?.value ?? [];
    final low = <({String name, int daysLeft})>[];

    for (final m in meds) {
      if (!m.isActive) continue;
      final remaining = m.pillsRemaining;
      if (remaining == null || remaining <= 0) continue;
      final dailyDoses = m.reminderTimes.isNotEmpty ? m.reminderTimes.length : 1;
      final daysLeft = (remaining / dailyDoses).floor();
      if (daysLeft <= 14) low.add((name: m.name, daysLeft: daysLeft));
    }

    if (low.isEmpty) return const SizedBox.shrink();
    low.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    final urgent = low.first.daysLeft <= 3;
    final cardColor = urgent ? AppColors.destructive : AppColors.warning;

    return BentoCard(
      color: cardColor.withValues(alpha: 0.07),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: cardColor, size: 15),
          const SizedBox(width: 6),
          Text(urgent ? 'Refill urgently needed' : 'Medicine refill needed',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cardColor)),
        ]),
        const SizedBox(height: 8),
        ...low.take(3).map((med) {
          final c = med.daysLeft <= 3 ? AppColors.destructive : med.daysLeft <= 7 ? AppColors.warning : AppColors.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(child: Text(med.name, style: const TextStyle(fontSize: 12))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  med.daysLeft == 0 ? 'Out today' : '~${med.daysLeft} day${med.daysLeft == 1 ? '' : 's'} left',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Daily snapshot row ────────────────────────────────────────────────────────
class _DailySnapshotRow extends StatelessWidget {
  final AsyncValue<List<Medicine>> medsAsync;
  final int? medStreak;
  final AsyncValue<List<Appointment>> apptsAsync;

  const _DailySnapshotRow({required this.medsAsync, required this.medStreak, required this.apptsAsync});

  @override
  Widget build(BuildContext context) {
    final meds = medsAsync.asData?.value ?? [];
    final active = meds.where((m) => m.isActive).toList();
    final taken = active.where((m) => m.takenToday).length;

    final appts = apptsAsync.asData?.value ?? [];
    final now = DateTime.now();
    final upcoming = appts.where((a) => (a.isConfirmed || a.isPending) && a.scheduledAt != null && a.scheduledAt!.isAfter(now)).toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    int? daysToAppt;
    if (upcoming.isNotEmpty) {
      final apptDay = DateTime(upcoming.first.scheduledAt!.year, upcoming.first.scheduledAt!.month, upcoming.first.scheduledAt!.day);
      daysToAppt = apptDay.difference(DateTime(now.year, now.month, now.day)).inDays;
    }

    final medColor = active.isEmpty ? AppColors.mutedForeground : taken == active.length ? AppColors.success : AppColors.primary;
    final streakColor = (medStreak ?? 0) > 0 ? const Color(0xFFF59E0B) : AppColors.mutedForeground;
    final visitColor = daysToAppt == null ? AppColors.mutedForeground : daysToAppt == 0 ? AppColors.success : daysToAppt <= 6 ? AppColors.warning : AppColors.primary;

    return Row(children: [
      Expanded(child: GestureDetector(
        onTap: () => context.go('/care'),
        child: _SnapshotChip(value: active.isEmpty ? '--' : '$taken/${active.length}', label: 'medicines', color: medColor),
      )),
      const SizedBox(width: 8),
      Expanded(child: _SnapshotChip(value: '${medStreak ?? 0}', label: 'day streak', color: streakColor)),
      const SizedBox(width: 8),
      Expanded(child: GestureDetector(
        onTap: () => context.go('/appointments'),
        child: _SnapshotChip(
          value: daysToAppt == null ? '--' : daysToAppt == 0 ? 'today' : '${daysToAppt}d',
          label: 'next visit',
          color: visitColor,
        ),
      )),
    ]);
  }
}

class _SnapshotChip extends StatelessWidget {
  final String value, label;
  final Color color;
  const _SnapshotChip({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ]),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Medicine Adherence Ring ───────────────────────────────────────────────────
class _AdherenceRingCard extends ConsumerWidget {
  final String uid;
  const _AdherenceRingCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamProfile = ref.watch(gamificationProvider(uid)).asData?.value;
    final weeklyMedDays = gamProfile?.weeklyMedDays ?? 0;
    final percent = (weeklyMedDays / 7.0).clamp(0.0, 1.0);

    final Color color;
    final String message;
    if (percent >= 0.86) {
      color = AppColors.success;
      message = 'Outstanding — consistent medicines all week.';
    } else if (percent >= 0.57) {
      color = AppColors.warning;
      message = 'Good progress — aim for 6 of 7 days.';
    } else if (percent > 0) {
      color = AppColors.destructive;
      message = 'Let\'s improve — try not to miss more than one day.';
    } else {
      color = AppColors.mutedForeground;
      message = 'Start your streak — every dose counts.';
    }

    return BentoCard(
      child: Row(children: [
        CircularPercentIndicator(
          radius: 38.0,
          lineWidth: 7.0,
          percent: percent,
          center: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$weeklyMedDays', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            Text('/7', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          ]),
          progressColor: color,
          backgroundColor: color.withValues(alpha: 0.12),
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animationDuration: 800,
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Weekly Adherence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, height: 1.4)),
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(7, (i) {
            final filled = i < weeklyMedDays;
            const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
            return Container(
              width: 24, height: 24,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? color.withValues(alpha: 0.15) : AppColors.muted,
                border: Border.all(color: filled ? color.withValues(alpha: 0.4) : AppColors.border),
              ),
              child: Center(
                child: Text(days[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: filled ? color : AppColors.mutedForeground)),
              ),
            );
          })),
        ])),
      ]),
    );
  }
}

// ── Family Status Bar ─────────────────────────────────────────────────────────
class _FamilyStatusBar extends ConsumerWidget {
  final String uid;
  const _FamilyStatusBar({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider(uid)).asData?.value ?? [];
    if (members.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Your Family', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
      const SizedBox(height: 10),
      SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _FamilyStatusChip(uid: uid, member: members[i]),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

class _FamilyStatusChip extends ConsumerWidget {
  final String uid;
  final FamilyMember member;
  const _FamilyStatusChip({required this.uid, required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(familyMemberMedicinesProvider((uid: uid, memberId: member.id)));
    final dotColor = _statusColor(medsAsync);

    return GestureDetector(
      onTap: () => context.go('/care'),
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
              child: member.photoUrl == null
                  ? Text(member.initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))
                  : null,
            ),
            Positioned(
              bottom: -1, right: -1,
              child: Container(
                width: 11, height: 11,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 1.5)),
              ),
            ),
          ]),
          const SizedBox(height: 5),
          SizedBox(
            width: 52,
            child: Text(member.name.split(' ').first, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }

  Color _statusColor(AsyncValue<List<Medicine>> medsAsync) {
    final meds = medsAsync.asData?.value;
    if (meds == null) return AppColors.mutedForeground;
    final active = meds.where((m) => m.isActive).toList();
    if (active.isEmpty) return AppColors.mutedForeground;
    if (active.any((m) => m.hasMissedSlot && !m.hasDueSlot)) return AppColors.destructive;
    if (active.any((m) => m.hasDueSlot)) return AppColors.warning;
    if (active.every((m) => m.takenToday)) return AppColors.success;
    return AppColors.mutedForeground;
  }
}

// ── Daily Awareness Card ──────────────────────────────────────────────────────
class _DailyAwarenessCard extends ConsumerWidget {
  final String uid;
  const _DailyAwarenessCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicinesProvider(uid)).asData?.value ?? [];
    final meals = ref.watch(todayMealsProvider(uid)).asData?.value ?? [];

    final hasMissedMed = meds.any((m) => m.isActive && m.hasMissedSlot);
    final loggedTypes = meals.map((m) => m.mealType).toSet();
    final h = DateTime.now().hour;
    final hasMissedMeal =
        (h >= 11 && !loggedTypes.contains(AppConstants.mealBreakfast)) ||
        (h >= 16 && !loggedTypes.contains(AppConstants.mealLunch)) ||
        (h >= 23 && !loggedTypes.contains(AppConstants.mealDinner));

    if (!hasMissedMed && !hasMissedMeal) return const SizedBox.shrink();

    final String message;
    if (hasMissedMed && hasMissedMeal) {
      message = 'You missed your medicine and a meal — please ensure you take them on time to stay on track.';
    } else if (hasMissedMed) {
      message = 'You missed one or more scheduled medicine doses. Please take them as soon as possible to stay on track.';
    } else {
      message = "You haven't logged a meal on time. Keeping track of your meals helps you stay on top of your health.";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BentoCard(
        color: AppColors.warningLight,
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: HugeIcons.strokeRoundedAlertDiamond, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Stay on track',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning)),
              const SizedBox(height: 4),
              Text(message,
                  style: const TextStyle(fontSize: 12, color: AppColors.foreground, height: 1.4)),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: () => context.go('/care'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text('Go to Medicines & Meals'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Upcoming Tasks Card ───────────────────────────────────────────────────────
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
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meds = ref.watch(medicinesProvider(widget.uid)).asData?.value ?? [];
    final meals = ref.watch(todayMealsProvider(widget.uid)).asData?.value ?? [];

    final actionableMeds = meds.where((m) =>
      m.isActive && (m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot || m.hasMissedSlot)
    ).toList();

    final currentMeal = _currentMealType();
    final loggedTypes = meals.map((m) => m.mealType).toSet();
    final hasActionableMeal = currentMeal != null && !loggedTypes.contains(currentMeal);
    final totalPending = actionableMeds.length + (hasActionableMeal ? 1 : 0);

    final header = Row(children: [
      const Expanded(child: Text('What needs to be done now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      if (totalPending > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('$totalPending left', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: AppColors.success, size: 12),
            SizedBox(width: 4),
            Text('All done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
          ]),
        ),
    ]);

    if (totalPending == 0 && actionableMeds.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: BentoCard(
            child: Column(children: [
              const SizedBox(height: 8),
              HugeIcon(icon: HugeIcons.strokeRoundedAward01, color: AppColors.success, size: 32),
              SizedBox(height: 8),
              Text("You're all caught up!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text('Great job keeping up with your health today.', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              SizedBox(height: 8),
            ]),
          ),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header,
      const SizedBox(height: 12),
      if (actionableMeds.isNotEmpty) ...[
        _MedsGroupCard(meds: actionableMeds, uid: widget.uid),
        const SizedBox(height: 10),
      ],
      _MealStatusCard(
        meals: meals,
        currentMeal: currentMeal,
        onLogMeal: (type) => showLogMealSheet(context, widget.uid, initialType: type),
      ),
      const SizedBox(height: 12),
    ]);
  }

  String? _currentMealType() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return AppConstants.mealBreakfast;
    if (h >= 11 && h < 16) return AppConstants.mealLunch;
    if (h >= 16 && h < 23) return AppConstants.mealDinner;
    return null;
  }
}

// ── Meds Group Card ───────────────────────────────────────────────────────────
class _MedsGroupCard extends ConsumerWidget {
  final List<Medicine> meds;
  final String uid;
  const _MedsGroupCard({required this.meds, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = meds.take(3).toList();
    final overflow = meds.length - 3;

    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < display.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _MedRow(medicine: display[i], uid: uid),
          ],
          if (overflow > 0) ...[
            const Divider(height: 1, color: AppColors.border),
            GestureDetector(
              onTap: () => context.go('/care'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Center(
                  child: Text('+$overflow more — see all in Medicines',
                      style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Med Row ───────────────────────────────────────────────────────────────────
class _MedRow extends ConsumerWidget {
  final Medicine medicine;
  final String uid;
  const _MedRow({required this.medicine, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMissed = medicine.hasMissedSlot && !medicine.hasDueSlot;
    final slot = isMissed
        ? medicine.todaySlots.where((s) => s.isMissed).firstOrNull
        : medicine.nextPendingSlot;
    final subtitle = slot != null
        ? (isMissed ? 'Missed · ${slot.displayTime}' : '${medicine.dosage} · Due at ${slot.displayTime}')
        : '${medicine.dosage} · ${medicine.frequency}';
    final totalSlots = medicine.todaySlots.length;
    final takenSlots = medicine.todaySlots.where((s) => s.isTaken).length;
    final iconColor = isMissed ? AppColors.warning : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(medicine.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (totalSlots > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(20)),
                child: Text('$takenSlots/$totalSlots', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              ),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: isMissed ? AppColors.warning : AppColors.mutedForeground)),
        ])),
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
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(10)),
            child: Text(isMissed ? 'Log' : 'Take',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Meal Status Card ──────────────────────────────────────────────────────────
class _MealStatusCard extends StatelessWidget {
  final List<MealLog> meals;
  final String? currentMeal;
  final void Function(String) onLogMeal;
  const _MealStatusCard({required this.meals, required this.currentMeal, required this.onLogMeal});

  static const _allMeals = [AppConstants.mealBreakfast, AppConstants.mealLunch, AppConstants.mealDinner];

  static Widget _mealIcon(String meal, Color color) {
    if (meal == AppConstants.mealBreakfast) return HugeIcon(icon: HugeIcons.strokeRoundedSun01, color: color, size: 18);
    if (meal == AppConstants.mealLunch) return HugeIcon(icon: HugeIcons.strokeRoundedSun01, color: color, size: 18);
    return HugeIcon(icon: HugeIcons.strokeRoundedMoon, color: color, size: 18);
  }

  @override
  Widget build(BuildContext context) {
    final loggedTypes = meals.map((m) => m.mealType).toSet();
    final h = DateTime.now().hour;

    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < _allMeals.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _MealRow(
              mealType: _allMeals[i],
              isCurrent: _allMeals[i] == currentMeal,
              isLogged: loggedTypes.contains(_allMeals[i]),
              isPast: _isPast(_allMeals[i], h),
              onLog: () => onLogMeal(_allMeals[i]),
              iconBuilder: _mealIcon,
            ),
          ],
        ],
      ),
    );
  }

  static bool _isPast(String meal, int h) {
    if (meal == AppConstants.mealBreakfast) return h >= 11;
    if (meal == AppConstants.mealLunch) return h >= 16;
    if (meal == AppConstants.mealDinner) return h >= 23;
    return false;
  }
}

// ── Meal Row ──────────────────────────────────────────────────────────────────
class _MealRow extends StatelessWidget {
  final String mealType;
  final bool isCurrent, isLogged, isPast;
  final VoidCallback onLog;
  final Widget Function(String meal, Color color) iconBuilder;

  const _MealRow({
    required this.mealType,
    required this.isCurrent,
    required this.isLogged,
    required this.isPast,
    required this.onLog,
    required this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurrent && !isLogged) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: iconBuilder(mealType, AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mealType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Text("Haven't logged yet", style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onLog,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
              child: const Text('Log', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
    }

    final Color statusColor;
    final String statusLabel;
    if (isLogged) {
      statusColor = AppColors.success;
      statusLabel = 'Logged';
    } else if (isPast) {
      statusColor = AppColors.warning;
      statusLabel = 'Missed';
    } else {
      statusColor = AppColors.mutedForeground;
      statusLabel = 'Upcoming';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        iconBuilder(mealType, AppColors.mutedForeground),
        const SizedBox(width: 10),
        Expanded(child: Text(mealType, style: const TextStyle(fontSize: 13, color: AppColors.foreground))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Caregiver Home Content
// ══════════════════════════════════════════════════════════════════════════════
class _CaregiverHomeContent extends ConsumerStatefulWidget {
  final AppUser user;
  const _CaregiverHomeContent({required this.user});
  @override
  ConsumerState<_CaregiverHomeContent> createState() => _CaregiverHomeContentState();
}

class _CaregiverHomeContentState extends ConsumerState<_CaregiverHomeContent> {
  String? _selectedMemberId;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good Morning';
    if (h >= 12 && h < 17) return 'Good Afternoon';
    if (h >= 17 && h < 23) return 'Good Evening';
    return 'Good Night';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider(widget.user.uid));
    final connectedPatientsAsync = ref.watch(caregiverPatientsProvider(widget.user.uid));
    final pendingInvitesAsync = ref.watch(pendingInvitesForEmailProvider(widget.user.email ?? ''));
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return membersAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'))),
      data: (members) {
        if (_selectedMemberId == null && members.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _selectedMemberId = members.first.id));
        }
        final selectedMember = members.where((m) => m.id == _selectedMemberId).firstOrNull;

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              Text(widget.user.name.isNotEmpty ? widget.user.name : 'Caregiver',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.foreground)),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(today, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ),
              ),
            ),
            actions: const [NotifBell()],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(familyMembersProvider(widget.user.uid));
              if (_selectedMemberId != null) ref.invalidate(familyMemberMedicinesProvider((uid: widget.user.uid, memberId: _selectedMemberId!)));
            },
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  // Pending invites
                  ...((pendingInvitesAsync.asData?.value ?? []).map((inv) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BentoCard(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AcceptInviteScreen(connection: inv))),
                      child: Row(children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedShield01, color: const Color(0xFF7C3AED), size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${inv.patientName} invited you to their Care Circle',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: const Color(0xFF7C3AED), size: 16),
                      ]),
                    ),
                  ))),

                  // My patients
                  ...((connectedPatientsAsync.asData?.value ?? []).isNotEmpty ? [
                    const Text('My Patients', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                    const SizedBox(height: 10),
                    ...((connectedPatientsAsync.asData?.value ?? []).map((conn) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BentoCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaregiverPatientProfileScreen(connection: conn))),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            child: Text(_initials(conn.patientName),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(conn.patientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(conn.relationship.relationshipLabel, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          ])),
                          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.textTertiary, size: 16),
                        ]),
                      ),
                    ))),
                    const SizedBox(height: 12),
                  ] : []),

                  const Text('Who are you checking on today?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                  const SizedBox(height: 10),
                  if (members.isEmpty)
                    _EmptyMembersCard(caregiverUid: widget.user.uid)
                  else
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final m = members[i];
                          final selected = m.id == _selectedMemberId;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedMemberId = m.id),
                            child: Column(children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  border: Border.all(color: selected ? const Color(0xFFF59E0B) : AppColors.border, width: selected ? 2.5 : 1),
                                ),
                                child: Center(child: Text(m.initials,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: selected ? Colors.white : const Color(0xFFF59E0B)))),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(width: 60, child: Text(m.name.split(' ').first,
                                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? const Color(0xFFF59E0B) : AppColors.mutedForeground))),
                            ]),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  if (selectedMember != null) ...[
                    BentoSectionHeader(title: "${selectedMember.name}'s Overview"),
                    if (selectedMember.age != null) ...[
                      const SizedBox(height: 4),
                      Text('${selectedMember.age} yrs · ${selectedMember.relationship}',
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    ],
                    const SizedBox(height: 12),
                    _CaregiverMedSection(caregiverUid: widget.user.uid, memberId: selectedMember.id, memberName: selectedMember.name),
                    const SizedBox(height: 12),
                    _CaregiverQuickActions(caregiverUid: widget.user.uid, memberId: selectedMember.id),
                  ] else if (members.isNotEmpty) const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                ])),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _EmptyMembersCard extends StatelessWidget {
  final String caregiverUid;
  const _EmptyMembersCard({required this.caregiverUid});

  @override
  Widget build(BuildContext context) => BentoCard(
    child: Column(children: [
      const SizedBox(height: 4),
      HugeIcon(icon: HugeIcons.strokeRoundedGroup, color: const Color(0xFFF59E0B), size: 36),
      const SizedBox(height: 10),
      const Text('No family members yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('Go to Care to add the people you care for.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      const SizedBox(height: 14),
      OutlinedButton(
        onPressed: () => context.go('/care'),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B)), foregroundColor: const Color(0xFFF59E0B)),
        child: const Text('Go to Medicines', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 4),
    ]),
  );
}

class _CaregiverMedSection extends ConsumerWidget {
  final String caregiverUid, memberId, memberName;
  const _CaregiverMedSection({required this.caregiverUid, required this.memberId, required this.memberName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(familyMemberMedicinesProvider((uid: caregiverUid, memberId: memberId)));
    return medsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
      data: (meds) {
        final activeMeds = meds.where((m) => m.isActive).toList();
        final takenToday = activeMeds.where((m) => m.takenToday).length;
        final dueMeds = activeMeds.where((m) => m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BentoRow(
            left: BentoStatCard(
              label: 'taken today',
              value: '$takenToday/${activeMeds.length}',
              icon: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.primary, size: 18),
              iconBgColor: AppColors.primaryTint,
              iconColor: AppColors.primary,
            ),
            right: BentoStatCard(
              label: dueMeds.isNotEmpty ? 'due now' : 'all done',
              value: '${dueMeds.length}',
              icon: dueMeds.isNotEmpty
                  ? HugeIcon(icon: HugeIcons.strokeRoundedAlarmClock, color: AppColors.warning, size: 18)
                  : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: AppColors.success, size: 18),
              iconBgColor: dueMeds.isNotEmpty ? AppColors.warningLight : AppColors.successLight,
              iconColor: dueMeds.isNotEmpty ? AppColors.warning : AppColors.success,
            ),
          ),
          if (activeMeds.isEmpty) ...[
            const SizedBox(height: 12),
            BentoCard(
              child: Column(children: [
                const SizedBox(height: 8),
                HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.mutedForeground, size: 28),
                const SizedBox(height: 8),
                Text('No medicines for $memberName yet', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                const SizedBox(height: 8),
              ]),
            ),
          ] else if (dueMeds.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Due now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...dueMeds.take(3).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CaregiverMedTile(medicine: m, caregiverUid: caregiverUid, memberId: memberId),
            )),
            if (dueMeds.length > 3)
              BentoCard(
                onTap: () => context.go('/care'),
                child: Center(child: Text('+${dueMeds.length - 3} more — see all in Medicines',
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500))),
              ),
          ] else ...[
            const SizedBox(height: 12),
            BentoCard(
              color: AppColors.successLight,
              child: Column(children: [
                const SizedBox(height: 4),
                HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: AppColors.success, size: 28),
                SizedBox(height: 6),
                Text('All medicines taken!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                SizedBox(height: 4),
              ]),
            ),
          ],
        ]);
      },
    );
  }
}

class _CaregiverMedTile extends ConsumerWidget {
  final Medicine medicine;
  final String caregiverUid, memberId;
  const _CaregiverMedTile({required this.medicine, required this.caregiverUid, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = medicine.nextPendingSlot;
    final subtitle = slot != null ? '${medicine.dosage} · Due at ${slot.displayTime}' : '${medicine.dosage} · ${medicine.frequency}';

    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(medicine.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () async { await ref.read(familyMedicinePatchProvider).logDose(caregiverUid, memberId, medicine.id); },
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: const Text('Give', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class _CaregiverQuickActions extends StatelessWidget {
  final String caregiverUid, memberId;
  const _CaregiverQuickActions({required this.caregiverUid, required this.memberId});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const BentoSectionHeader(title: 'Quick Actions'),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _ActionBtn(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.primary, size: 22),
        label: 'Add Medicine', color: AppColors.primary, onTap: () => context.go('/care'),
      )),
      const SizedBox(width: 10),
      Expanded(child: _ActionBtn(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: const Color(0xFFF59E0B), size: 22),
        label: 'Appointments', color: const Color(0xFFF59E0B), onTap: () => context.go('/appointments'),
      )),
      const SizedBox(width: 10),
      Expanded(child: _ActionBtn(
        icon: HugeIcon(icon: HugeIcons.strokeRoundedUserAdd01, color: AppColors.success, size: 22),
        label: 'Add Member', color: AppColors.success, onTap: () => context.go('/care'),
      )),
    ]),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        icon,
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}
