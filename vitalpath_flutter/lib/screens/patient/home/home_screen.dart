import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/hydration_provider.dart';
import '../../../models/app_user.dart';
import '../../../models/family_member.dart';
import '../../../models/medicine.dart';
import '../../../models/meal.dart';
import '../../../models/appointment.dart';
import '../../../core/constants/app_constants.dart';
import '../care/care_screen.dart';
import '../../../providers/vitals_provider.dart';
import '../../../models/vital_reading.dart';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.notifications_off_outlined, color: AppColors.warning, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notifications off',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            const Text('Enable to receive medicine reminders.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                await openAppSettings();
                ref.invalidate(notifPermGrantedProvider);
              },
              child: const Text('Open Settings',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary, decoration: TextDecoration.underline)),
            ),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.mutedForeground),
          onPressed: () => setState(() => _dismissed = true),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
        ),
      ]),
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
      children: invites.map((inv) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AcceptInviteScreen(connection: inv))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${inv.patientName} invited you to their Care Circle',
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                const Text('Tap to view and accept or decline',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedForeground)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF7C3AED)),
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
    final vitalsAsync = ref.watch(vitalsProvider(user.uid));
    final gamAsync = ref.watch(gamificationProvider(user.uid));
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting(), style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          Text(
            user.name.isNotEmpty ? user.name : 'Patient',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground),
          ),
        ]),
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
          ref.invalidate(vitalsProvider(user.uid));
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── SNAPSHOT: TODAY'S HEALTH AT A GLANCE ──────────────────
                  _DailySnapshotRow(
                    medsAsync: medsAsync,
                    medStreak: gamAsync.asData?.value.medStreak,
                    apptsAsync: apptsAsync,
                  ),
                  const SizedBox(height: 16),

                  // ── TIER 0: ALERTS ─────────────────────────────────────────
                  const _NotifPermBanner(),
                  _PendingInviteBanner(email: user.email ?? ''),
                  _AbnormalVitalAlerts(vitalsAsync: vitalsAsync),

                  // ── TIER 1: NICHE HIGH-VALUE SECTIONS ─────────────────────
                  // Morning check-in (6am–10am only, once per day)
                  _MorningCheckinCard(uid: user.uid),
                  // Hydration tracker (11am onwards)
                  _HydrationTracker(),
                  const SizedBox(height: 6),

                  // ── TIER 2: TODAY'S ACTIONS ────────────────────────────────
                  _EndOfDayAwarenessCard(uid: user.uid),
                  _UpcomingTasksCard(uid: user.uid),
                  const SizedBox(height: 20),

                  // ── TIER 3: DAILY STATUS ───────────────────────────────────
                  _CaregiversActiveBanner(uid: user.uid),
                  const SizedBox(height: 14),

                  // ── TIER 4: CONTEXT ────────────────────────────────────────
                  _AppointmentSection(apptsAsync: apptsAsync),
                  _TimeContextualCard(uid: user.uid, medsAsync: medsAsync, mealsAsync: mealsAsync),
                  const SizedBox(height: 10),
                  _RefillCountdownCard(medsAsync: medsAsync),

                  // ── TIER 5: NUMBERS & EXPLORATION ─────────────────────────
                  const SizedBox(height: 4),
                  _AdherenceRingCard(uid: user.uid),
                  const SizedBox(height: 14),
                  _FamilyStatusBar(uid: user.uid),

                  // AI Insights — below the fold
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
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('AI Health Insights', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                          Text('Personalised suggestions from Claude AI', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                        ])),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 24),
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
    if (h < 5) return 'Good Night';
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }
}

// ── TIER 1: Morning check-in ──────────────────────────────────────────────────
class _MorningCheckinCard extends ConsumerStatefulWidget {
  final String uid;
  const _MorningCheckinCard({required this.uid});
  @override
  ConsumerState<_MorningCheckinCard> createState() => _MorningCheckinCardState();
}

class _MorningCheckinCardState extends ConsumerState<_MorningCheckinCard> {
  String? _sleep;
  String? _feeling;
  bool _submitted = false;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _submit() {
    if (_sleep == null || _feeling == null) return;
    ref.read(checkinProvider.notifier).checkIn(sleepQuality: _sleep!, feeling: _feeling!);
    setState(() => _submitted = true);
    _dismissTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 6 || h >= 10) return const SizedBox.shrink();

    final checkinState = ref.watch(checkinProvider);
    if (checkinState.isCheckedInToday) return const SizedBox.shrink();

    if (_submitted) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          SizedBox(width: 10),
          Text('Morning logged — have a great day!',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.success, fontFamily: 'Inter')),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.wb_sunny_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          const Text('Morning check-in',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          const Spacer(),
          Text(DateFormat('EEE d MMM').format(DateTime.now()),
              style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 14),

        // Sleep question
        const Text('How did you sleep?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        const SizedBox(height: 8),
        Row(children: [
          _CheckinOption('Well', Icons.bedtime_rounded, AppColors.success, _sleep == 'well', () => setState(() => _sleep = 'well')),
          const SizedBox(width: 8),
          _CheckinOption('Okay', Icons.bedtime_outlined, AppColors.warning, _sleep == 'okay', () => setState(() => _sleep = 'okay')),
          const SizedBox(width: 8),
          _CheckinOption('Poorly', Icons.nightlight_rounded, AppColors.destructive, _sleep == 'poorly', () => setState(() => _sleep = 'poorly')),
        ]),

        const SizedBox(height: 14),

        // Feeling question
        const Text('How are you feeling?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        const SizedBox(height: 8),
        Row(children: [
          _CheckinOption('Great', Icons.sentiment_very_satisfied_rounded, AppColors.success, _feeling == 'great', () => setState(() => _feeling = 'great')),
          const SizedBox(width: 6),
          _CheckinOption('Good', Icons.sentiment_satisfied_rounded, AppColors.primary, _feeling == 'good', () => setState(() => _feeling = 'good')),
          const SizedBox(width: 6),
          _CheckinOption('Off', Icons.sentiment_neutral_rounded, AppColors.warning, _feeling == 'off', () => setState(() => _feeling = 'off')),
          const SizedBox(width: 6),
          _CheckinOption('Unwell', Icons.sentiment_dissatisfied_rounded, AppColors.destructive, _feeling == 'unwell', () => setState(() => _feeling = 'unwell')),
        ]),

        if (_sleep != null && _feeling != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
              child: const Text('Log Morning Check-in'),
            ),
          ),
        ],
      ]),
    );
  }
}

class _CheckinOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CheckinOption(this.label, this.icon, this.color, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.muted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: selected ? color : AppColors.mutedForeground, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? color : AppColors.mutedForeground, fontFamily: 'Inter'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── TIER 1: Hydration tracker ─────────────────────────────────────────────────
class _HydrationTracker extends ConsumerWidget {
  const _HydrationTracker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (DateTime.now().hour < 11) return const SizedBox.shrink();

    final cups = ref.watch(hydrationProvider);
    final notifier = ref.read(hydrationProvider.notifier);

    final Color color;
    final String message;
    if (cups >= 8) {
      color = AppColors.success;
      message = 'Daily goal reached! Great hydration today.';
    } else if (cups >= 5) {
      color = AppColors.primary;
      message = 'Good progress — keep it going!';
    } else if (cups >= 3) {
      color = AppColors.warning;
      message = 'Halfway there — try to drink more.';
    } else {
      color = AppColors.destructive;
      message = cups == 0 ? 'Don\'t forget to drink water today.' : 'Stay hydrated — $cups of 8 cups logged.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.water_drop_rounded, size: 15, color: Color(0xFF0EA5E9)),
          const SizedBox(width: 7),
          const Text('Hydration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          const Spacer(),
          Text('$cups / 8 cups', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 10),
        Row(
          children: List.generate(8, (i) {
            final filled = i < cups;
            return GestureDetector(
              onTap: filled
                  ? () => notifier.removeCup()
                  : () => notifier.addCup(),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: filled ? const Color(0xFF0EA5E9).withValues(alpha: 0.15) : AppColors.muted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: filled ? const Color(0xFF0EA5E9) : AppColors.border),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 15,
                  color: filled ? const Color(0xFF0EA5E9) : AppColors.mutedForeground.withValues(alpha: 0.35),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
      ]),
    );
  }
}


// ── TIER 0: Abnormal vital alerts ─────────────────────────────────────────────
class _AbnormalVitalAlerts extends StatelessWidget {
  final AsyncValue<List<VitalReading>> vitalsAsync;
  const _AbnormalVitalAlerts({required this.vitalsAsync});

  @override
  Widget build(BuildContext context) {
    final readings = vitalsAsync.asData?.value ?? [];
    if (readings.isEmpty) return const SizedBox.shrink();

    final latestByType = <String, VitalReading>{};
    for (final r in readings) {
      latestByType.putIfAbsent(r.type, () => r);
    }

    final alerts = latestByType.values
        .where((r) => !VitalType.isNormal(r.type, r.value))
        .toList()
      ..sort((a, b) => _severity(b).compareTo(_severity(a)));

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.map((r) {
        final tier = _severity(r);
        final Color alertColor = tier >= 3 ? AppColors.destructive : tier >= 2 ? AppColors.warning : AppColors.primary;
        final IconData alertIcon = tier >= 3 ? Icons.error_rounded : tier >= 2 ? Icons.warning_rounded : Icons.info_rounded;
        final String tierLabel = tier >= 3 ? 'Critical' : tier >= 2 ? 'Elevated' : 'Monitor';
        final (min, _) = VitalType.normalRange(r.type);
        final val = r.type == VitalType.temp ? r.value.toStringAsFixed(1) : r.value.toInt().toString();
        final dir = r.value < min ? 'below normal' : 'above normal';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => context.go('/vitals'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: alertColor.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(alertIcon, size: 20, color: alertColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$tierLabel: ${VitalType.labelFor(r.type)} ($val ${VitalType.unitFor(r.type)})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: alertColor, fontFamily: 'Inter')),
                    Text('${VitalType.labelFor(r.type)} is $dir — tap to review',
                        style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: alertColor.withValues(alpha: 0.7)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _severity(VitalReading r) {
    final (min, max) = VitalType.normalRange(r.type);
    final d = r.value < min ? (min - r.value) / min : (r.value - max) / max;
    if (d > 0.30) return 3;
    if (d > 0.15) return 2;
    return 1;
  }
}

// ── TIER 3: Zone 1 Health Status Card ─────────────────────────────────────────
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
        const Icon(Icons.shield_rounded, size: 13, color: Color(0xFF7C3AED)),
        const SizedBox(width: 6),
        Expanded(
          child: Text('$names $verb in your care circle',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        ),
        GestureDetector(
          onTap: () => context.push('/care-circle'),
          child: const Text('Manage', style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── TIER 4: Appointment section (countdown / prep card) ───────────────────────
class _AppointmentSection extends StatelessWidget {
  final AsyncValue<List<Appointment>> apptsAsync;
  const _AppointmentSection({required this.apptsAsync});

  @override
  Widget build(BuildContext context) {
    final appts = apptsAsync.asData?.value ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = appts
        .where((a) => (a.isConfirmed || a.isPending) && a.scheduledAt != null && a.scheduledAt!.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    final apptDay = DateTime(next.scheduledAt!.year, next.scheduledAt!.month, next.scheduledAt!.day);
    final daysUntil = apptDay.difference(today).inDays;

    if (daysUntil <= 3) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AppointmentPrepCard(appointment: next, daysUntil: daysUntil),
      );
    }

    final color = daysUntil <= 6 ? AppColors.warning : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.go('/appointments'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.event_rounded, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Next visit in $daysUntil day${daysUntil == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
              Text('Dr. ${next.doctorName}${next.doctorSpecialty != null ? " · ${next.doctorSpecialty}" : ""}',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ])),
            Icon(Icons.chevron_right_rounded, size: 18, color: color.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }
}

class _AppointmentPrepCard extends StatelessWidget {
  final Appointment appointment;
  final int daysUntil;
  const _AppointmentPrepCard({required this.appointment, required this.daysUntil});

  @override
  Widget build(BuildContext context) {
    final color = daysUntil == 0 ? AppColors.success : AppColors.warning;
    final timeStr = appointment.scheduledAt != null ? DateFormat('h:mm a').format(appointment.scheduledAt!) : '';
    const checklist = ['Bring your medicines list', 'Bring your BP and vitals log', 'Note any new symptoms', 'Bring prescription documents'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_available_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              daysUntil == 0 ? 'Doctor visit today — prepare now' : 'Visit in $daysUntil day${daysUntil == 1 ? '' : 's'} — get ready',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter'),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Dr. ${appointment.doctorName}${timeStr.isNotEmpty ? " · $timeStr" : ""}',
            style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        const SizedBox(height: 12),
        const Text('What to bring:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground, fontFamily: 'Inter')),
        const SizedBox(height: 6),
        ...checklist.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(Icons.check_box_outline_blank_rounded, size: 13, color: color),
            const SizedBox(width: 8),
            Text(item, style: const TextStyle(fontSize: 12, color: AppColors.foreground, fontFamily: 'Inter')),
          ]),
        )),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.go('/appointments'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('View appointment', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 13, color: color),
          ]),
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
      return _ContextCard(icon: Icons.wb_sunny_rounded, color: const Color(0xFFF59E0B),
        heading: 'Morning routine', actionLabel: dueMeds.isNotEmpty ? 'View Medicines' : 'Log Breakfast',
        body: dueMeds.isNotEmpty ? 'You have ${dueMeds.length} medicine${dueMeds.length == 1 ? '' : 's'} to take this morning.' : loggedTypes.contains(AppConstants.mealBreakfast) ? 'Breakfast done! Morning medicines all taken.' : 'Start your day — take your medicines and log breakfast.',
        onAction: () => dueMeds.isNotEmpty ? context.go('/care') : showLogMealSheet(context, uid, initialType: AppConstants.mealBreakfast));
    } else if (h >= 11 && h < 14) {
      return _ContextCard(icon: Icons.light_mode_rounded, color: AppColors.primary,
        heading: 'Midday check-in', actionLabel: loggedTypes.contains(AppConstants.mealLunch) ? 'Log Vitals' : 'Log Lunch',
        body: loggedTypes.contains(AppConstants.mealLunch) ? 'Lunch logged! A good time to check your blood pressure.' : 'Lunchtime — logging meals helps track your daily nutrition.',
        onAction: () => loggedTypes.contains(AppConstants.mealLunch) ? context.go('/vitals') : showLogMealSheet(context, uid, initialType: AppConstants.mealLunch));
    } else if (h >= 14 && h < 17) {
      return _ContextCard(icon: Icons.directions_run_rounded, color: AppColors.success,
        heading: 'Afternoon boost', actionLabel: 'Log Activity',
        body: 'Good time for a walk or light activity. Logging steps keeps you on track.',
        onAction: () => context.push('/activity'));
    } else if (h >= 17 && h < 21) {
      final eveningDue = meds.where((m) => m.isActive && m.hasDueSlot).toList();
      return _ContextCard(icon: Icons.nights_stay_rounded, color: const Color(0xFF7C3AED),
        heading: 'Evening routine', actionLabel: eveningDue.isNotEmpty ? 'View Medicines' : 'Log Dinner',
        body: eveningDue.isNotEmpty ? '${eveningDue.length} evening medicine${eveningDue.length == 1 ? '' : 's'} still due.' : loggedTypes.contains(AppConstants.mealDinner) ? 'Evening all done — great health day!' : 'Log dinner to complete your daily record.',
        onAction: () => eveningDue.isNotEmpty ? context.go('/care') : showLogMealSheet(context, uid, initialType: AppConstants.mealDinner));
    } else {
      final allDone = meds.where((m) => m.isActive).every((m) => m.takenToday);
      return _ContextCard(icon: Icons.bedtime_rounded, color: AppColors.mutedForeground,
        heading: 'End of day',
        body: allDone ? 'All medicines taken today — excellent health day!' : 'Check your medicines before bed to complete today\'s log.',
        actionLabel: 'View Summary',
        onAction: () => context.go('/care'));
    }
  }
}

class _ContextCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String heading, body, actionLabel;
  final VoidCallback onAction;
  const _ContextCard({required this.icon, required this.color, required this.heading, required this.body, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(heading, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.foreground, fontFamily: 'Inter', height: 1.4)),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.medication_rounded, size: 15, color: cardColor),
          const SizedBox(width: 6),
          Text(urgent ? 'Refill urgently needed' : 'Medicine refill needed',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cardColor, fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 8),
        ...low.take(3).map((med) {
          final c = med.daysLeft <= 3 ? AppColors.destructive : med.daysLeft <= 7 ? AppColors.warning : AppColors.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(child: Text(med.name, style: const TextStyle(fontSize: 12, fontFamily: 'Inter'))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  med.daysLeft == 0 ? 'Out today' : '~${med.daysLeft} day${med.daysLeft == 1 ? '' : 's'} left',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c, fontFamily: 'Inter'),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── TIER 5: Daily snapshot row (replaces 2×2 grid) ───────────────────────────
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontFamily: 'Inter'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
      ]),
    );
  }
}

// ── TIER 5: Medicine Adherence Ring ──────────────────────────────────────────
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        CircularPercentIndicator(
          radius: 38.0,
          lineWidth: 7.0,
          percent: percent,
          center: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$weeklyMedDays', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
            const Text('/7', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ]),
          progressColor: color,
          backgroundColor: color.withValues(alpha: 0.12),
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animationDuration: 800,
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Weekly Adherence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter', height: 1.4)),
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
                child: Text(days[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: filled ? color : AppColors.mutedForeground, fontFamily: 'Inter')),
              ),
            );
          })),
        ])),
      ]),
    );
  }
}

// ── TIER 5: Family Status Bar ─────────────────────────────────────────────────
class _FamilyStatusBar extends ConsumerWidget {
  final String uid;
  const _FamilyStatusBar({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider(uid)).asData?.value ?? [];
    if (members.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Your Family', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontFamily: 'Inter')),
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
      const SizedBox(height: 14),
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
      child: Container(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
              child: member.photoUrl == null
                  ? Text(member.initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Inter'))
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
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
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

// ── FOOTER: Emergency contacts strip ─────────────────────────────────────────

// ── End of Day Awareness Card ─────────────────────────────────────────────────
class _EndOfDayAwarenessCard extends ConsumerWidget {
  final String uid;
  const _EndOfDayAwarenessCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicinesProvider(uid)).asData?.value ?? [];
    final meals = ref.watch(todayMealsProvider(uid)).asData?.value ?? [];

    final hasMissedMed = meds.any((m) => m.isActive && m.hasMissedSlot);
    final loggedTypes = meals.map((m) => m.mealType).toSet();
    final h = DateTime.now().hour;
    final hasMissedMeal = (h >= 11 && !loggedTypes.contains(AppConstants.mealBreakfast)) ||
        (h >= 16 && !loggedTypes.contains(AppConstants.mealLunch)) ||
        (h >= 23 && !loggedTypes.contains(AppConstants.mealDinner));

    if (!hasMissedMed && !hasMissedMeal) return const SizedBox.shrink();

    final String message;
    if (hasMissedMed && hasMissedMeal) {
      message = "You haven't taken your medicine or logged your meals on time. It is important to stay on schedule.";
    } else if (hasMissedMed) {
      message = 'You have missed one or more scheduled medication doses today. Try to take them as soon as possible.';
    } else {
      message = "You haven't logged some meals today. Keeping track helps you stay on top of your health.";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mutedForeground.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bedtime_rounded, size: 18, color: AppColors.mutedForeground),
          ),
          const SizedBox(width: 10),
          const Text('End of day',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppColors.foreground)),
        ]),
        const SizedBox(height: 10),
        Text(message,
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter', height: 1.45)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => context.go('/care'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.mutedForeground.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text('View Summary',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppColors.foreground)),
          ),
        ),
      ]),
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
      const Expanded(child: Text('What needs to be done now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
      if (totalPending > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('$totalPending left', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Inter')),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_rounded, size: 12, color: AppColors.success),
            SizedBox(width: 4),
            Text('All done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success, fontFamily: 'Inter')),
          ]),
        ),
    ]);

    if (totalPending == 0 && actionableMeds.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: const Column(children: [
            Icon(Icons.celebration_rounded, size: 32, color: AppColors.success),
            SizedBox(height: 8),
            Text("You're all caught up!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            SizedBox(height: 2),
            Text('Great job keeping up with your health today.', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ]),
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
      const SizedBox(height: 20),
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
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
                      style: const TextStyle(fontSize: 13, color: AppColors.primary, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
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
          child: Icon(Icons.medication_rounded, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(medicine.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
            if (totalSlots > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(6)),
                child: Text('$takenSlots/$totalSlots', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: isMissed ? AppColors.warning : AppColors.mutedForeground, fontFamily: 'Inter')),
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
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
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
  static const _mealIcons = {
    'Breakfast': Icons.wb_sunny_rounded,
    'Lunch': Icons.light_mode_rounded,
    'Dinner': Icons.nights_stay_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final loggedTypes = meals.map((m) => m.mealType).toSet();
    final h = DateTime.now().hour;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _allMeals.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _MealRow(
              mealType: _allMeals[i],
              icon: _mealIcons[_allMeals[i]] ?? Icons.restaurant_rounded,
              isCurrent: _allMeals[i] == currentMeal,
              isLogged: loggedTypes.contains(_allMeals[i]),
              isPast: _isPast(_allMeals[i], h),
              onLog: () => onLogMeal(_allMeals[i]),
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
  final IconData icon;
  final bool isCurrent, isLogged, isPast;
  final VoidCallback onLog;
  const _MealRow({
    required this.mealType,
    required this.icon,
    required this.isCurrent,
    required this.isLogged,
    required this.isPast,
    required this.onLog,
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
            child: Icon(icon, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mealType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            const Text("Haven't logged yet", style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onLog,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
              child: const Text('Log', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
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
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 10),
        Expanded(child: Text(mealType, style: const TextStyle(fontSize: 13, fontFamily: 'Inter', color: AppColors.foreground))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor, fontFamily: 'Inter')),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Caregiver Home Content (unchanged logic, improved labels)
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
    if (h < 5) return 'Good Night';
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.surface,
            surfaceTintColor: AppColors.surface,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              Text(widget.user.name.isNotEmpty ? widget.user.name : 'Caregiver', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(today, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')))),
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
                padding: const EdgeInsets.all(20),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  ...((pendingInvitesAsync.asData?.value ?? []).map((inv) => GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AcceptInviteScreen(connection: inv))),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3))),
                      child: Row(children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${inv.patientName} invited you to their Care Circle', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13))),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF7C3AED)),
                      ]),
                    ),
                  ))),
                  ...((connectedPatientsAsync.asData?.value ?? []).isNotEmpty ? [
                    const Text('My Patients', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                    const SizedBox(height: 10),
                    ...((connectedPatientsAsync.asData?.value ?? []).map((conn) => GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaregiverPatientProfileScreen(connection: conn))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          CircleAvatar(radius: 22, backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12), child: Text(_initials(conn.patientName), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED), fontFamily: 'Inter'))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(conn.patientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                            Text(conn.relationship.relationshipLabel, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                          ])),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.mutedForeground),
                        ]),
                      ),
                    ))),
                    const SizedBox(height: 14),
                  ] : []),
                  const Text('Who are you checking on today?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontFamily: 'Inter')),
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
                                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B).withValues(alpha: 0.15), border: Border.all(color: selected ? const Color(0xFFF59E0B) : AppColors.border, width: selected ? 2.5 : 1)),
                                child: Center(child: Text(m.initials, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16, color: selected ? Colors.white : const Color(0xFFF59E0B)))),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(width: 60, child: Text(m.name.split(' ').first, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontFamily: 'Inter', fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? const Color(0xFFF59E0B) : AppColors.mutedForeground))),
                            ]),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (selectedMember != null) ...[
                    Row(children: [
                      Container(width: 6, height: 20, decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 10),
                      Text("${selectedMember.name}'s Overview", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                      if (selectedMember.age != null) ...[
                        const SizedBox(width: 6),
                        Text('· ${selectedMember.age} yrs · ${selectedMember.relationship}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    _CaregiverMedSection(caregiverUid: widget.user.uid, memberId: selectedMember.id, memberName: selectedMember.name),
                    const SizedBox(height: 20),
                    _CaregiverQuickActions(caregiverUid: widget.user.uid, memberId: selectedMember.id),
                  ] else if (members.isNotEmpty) const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 20),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))),
    child: Column(children: [
      const Icon(Icons.family_restroom_rounded, size: 36, color: Color(0xFFF59E0B)),
      const SizedBox(height: 10),
      const Text('No family members yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
      const SizedBox(height: 4),
      const Text('Go to Care to add the people you care for.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
      const SizedBox(height: 14),
      OutlinedButton(onPressed: () => context.go('/care'), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B)), foregroundColor: const Color(0xFFF59E0B)), child: const Text('Go to Medicines', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
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
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.medication_rounded, color: AppColors.primary, size: 20),
                const SizedBox(height: 6),
                Text('$takenToday/${activeMeds.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Inter')),
                const Text('taken today', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            )),
            const SizedBox(width: 10),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: dueMeds.isNotEmpty ? AppColors.warning.withValues(alpha: 0.07) : AppColors.success.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: dueMeds.isNotEmpty ? AppColors.warning.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(dueMeds.isNotEmpty ? Icons.alarm_rounded : Icons.check_circle_rounded, color: dueMeds.isNotEmpty ? AppColors.warning : AppColors.success, size: 20),
                const SizedBox(height: 6),
                Text('${dueMeds.length}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: dueMeds.isNotEmpty ? AppColors.warning : AppColors.success, fontFamily: 'Inter')),
                Text(dueMeds.isNotEmpty ? 'due now' : 'all done', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            )),
          ]),
          if (activeMeds.isEmpty) ...[
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                const Icon(Icons.medication_outlined, size: 28, color: AppColors.mutedForeground),
                const SizedBox(height: 8),
                Text('No medicines for $memberName yet', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            ),
          ] else if (dueMeds.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Due now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            ...dueMeds.take(3).map((m) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _CaregiverMedTile(medicine: m, caregiverUid: caregiverUid, memberId: memberId))),
            if (dueMeds.length > 3)
              GestureDetector(onTap: () => context.go('/care'), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Center(child: Text('+${dueMeds.length - 3} more — see all in Medicines', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontFamily: 'Inter', fontWeight: FontWeight.w500))))),
          ] else ...[
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
              child: const Column(children: [
                Icon(Icons.celebration_rounded, size: 28, color: AppColors.success),
                SizedBox(height: 6),
                Text('All medicines taken!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppColors.success)),
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

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(medicine.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async { await ref.read(familyMedicinePatchProvider).logDose(caregiverUid, memberId, medicine.id); },
            child: Container(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)), child: const Text('Give', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
          ),
        ]),
      ),
    );
  }
}

class _CaregiverQuickActions extends StatelessWidget {
  final String caregiverUid, memberId;
  const _CaregiverQuickActions({required this.caregiverUid, required this.memberId});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _ActionBtn(icon: Icons.medication_rounded, label: 'Add Medicine', color: AppColors.primary, onTap: () => context.go('/care'))),
      const SizedBox(width: 10),
      Expanded(child: _ActionBtn(icon: Icons.calendar_month_rounded, label: 'Appointments', color: const Color(0xFFF59E0B), onTap: () => context.go('/appointments'))),
      const SizedBox(width: 10),
      Expanded(child: _ActionBtn(icon: Icons.person_add_rounded, label: 'Add Member', color: AppColors.success, onTap: () => context.go('/care'))),
    ]),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
      ]),
    ),
  );
}
