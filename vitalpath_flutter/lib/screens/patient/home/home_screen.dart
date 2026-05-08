import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

                  // ── TIER 0: ALERTS ─────────────────────────────────────────
                  const _NotifPermBanner(),
                  _PendingInviteBanner(email: user.email ?? ''),
                  _AbnormalVitalAlerts(vitalsAsync: vitalsAsync),

                  // ── TIER 1: NICHE HIGH-VALUE SECTIONS ─────────────────────
                  // Morning check-in (6am–10am only, once per day)
                  _MorningCheckinCard(uid: user.uid),
                  // Hydration tracker (11am onwards)
                  _HydrationTracker(),
                  // Symptom quick log (always available, compact)
                  _SymptomQuickLog(uid: user.uid),
                  const SizedBox(height: 6),

                  // ── TIER 2: TODAY'S ACTIONS ────────────────────────────────
                  const _SectionLabel('What needs doing now'),
                  const SizedBox(height: 10),
                  _UpcomingTasksCard(uid: user.uid),
                  const SizedBox(height: 20),

                  // ── TIER 3: DAILY STATUS ───────────────────────────────────
                  _Zone1StatusCard(user: user, vitalsAsync: vitalsAsync, medsAsync: medsAsync),
                  const SizedBox(height: 6),
                  _CaregiversActiveBanner(uid: user.uid),
                  const SizedBox(height: 14),

                  // ── TIER 4: CONTEXT ────────────────────────────────────────
                  _AppointmentSection(apptsAsync: apptsAsync),
                  _TimeContextualCard(uid: user.uid, medsAsync: medsAsync, mealsAsync: mealsAsync),
                  const SizedBox(height: 10),
                  _RefillCountdownCard(medsAsync: medsAsync),

                  // ── TIER 5: NUMBERS & EXPLORATION ─────────────────────────
                  const _SectionLabel("Today's health at a glance"),
                  const SizedBox(height: 10),
                  _DailySnapshotRow(
                    medsAsync: medsAsync,
                    medStreak: gamAsync.asData?.value.medStreak,
                    apptsAsync: apptsAsync,
                  ),
                  const SizedBox(height: 14),
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

                  // ── FOOTER: EMERGENCY CONTACTS ─────────────────────────────
                  _EmergencyContactsStrip(uid: user.uid, apptsAsync: apptsAsync),
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

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontFamily: 'Inter', letterSpacing: 0.2),
    );
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

// ── TIER 1: Symptom quick log ─────────────────────────────────────────────────
class _SymptomQuickLog extends StatelessWidget {
  final String uid;
  const _SymptomQuickLog({required this.uid});

  static const _symptoms = [
    'Headache', 'Chest pain', 'Dizziness', 'Nausea',
    'Fatigue', 'Shortness of breath', 'Joint pain', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(children: [
          Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.mutedForeground),
          SizedBox(width: 10),
          Expanded(
            child: Text('Log a symptom',
                style: TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.mutedForeground),
        ]),
      ),
    );
  }

  void _show(BuildContext context) {
    String? selected;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What are you experiencing?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              const SizedBox(height: 6),
              const Text('Select the symptom that best describes how you feel.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _symptoms.map((s) => GestureDetector(
                  onTap: () => setModalState(() => selected = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected == s ? AppColors.destructive.withValues(alpha: 0.1) : AppColors.muted,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected == s ? AppColors.destructive : AppColors.border),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 13, fontWeight: selected == s ? FontWeight.w600 : FontWeight.w400, color: selected == s ? AppColors.destructive : AppColors.foreground, fontFamily: 'Inter')),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Symptom logged: $selected'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ));
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                    disabledBackgroundColor: AppColors.border,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Log Symptom', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
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
class _Zone1StatusCard extends ConsumerWidget {
  final AppUser user;
  final AsyncValue<List<VitalReading>> vitalsAsync;
  final AsyncValue<List<Medicine>> medsAsync;

  const _Zone1StatusCard({required this.user, required this.vitalsAsync, required this.medsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamProfile = ref.watch(gamificationProvider(user.uid)).asData?.value;
    final meds = medsAsync.asData?.value ?? [];
    final readings = vitalsAsync.asData?.value ?? [];

    final activeMeds = meds.where((m) => m.isActive).toList();
    final missedMeds = activeMeds.where((m) => m.hasMissedSlot && !m.hasDueSlot).toList();
    final abnormalReadings = readings.where((r) => !VitalType.isNormal(r.type, r.value)).toList();

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (missedMeds.isNotEmpty && abnormalReadings.isNotEmpty) {
      statusColor = AppColors.destructive;
      statusText = 'Needs attention';
      statusIcon = Icons.warning_rounded;
    } else if (missedMeds.isNotEmpty || abnormalReadings.isNotEmpty) {
      statusColor = AppColors.warning;
      statusText = 'Check in today';
      statusIcon = Icons.info_rounded;
    } else if (activeMeds.isNotEmpty && activeMeds.every((m) => m.takenToday)) {
      statusColor = AppColors.success;
      statusText = 'On track';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = AppColors.primary;
      statusText = 'Good day';
      statusIcon = Icons.wb_sunny_rounded;
    }

    final medStreak = gamProfile?.medStreak ?? 0;
    final latestBpSys = readings.where((r) => r.type == VitalType.bpSystolic).firstOrNull;
    final latestBpDia = readings.where((r) => r.type == VitalType.bpDiastolic).firstOrNull;
    final latestPulse = readings.where((r) => r.type == VitalType.pulse).firstOrNull;
    final latestGlucose = readings.where((r) => r.type == VitalType.glucose).firstOrNull;
    final vitalSummary = _interpret(latestBpSys, latestBpDia, latestPulse, latestGlucose);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withValues(alpha: 0.08), statusColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 13, color: statusColor),
              const SizedBox(width: 5),
              Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor, fontFamily: 'Inter')),
            ]),
          ),
          const Spacer(),
          if (medStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text('$medStreak day streak', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B), fontFamily: 'Inter')),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        Text(vitalSummary, style: const TextStyle(fontSize: 13, fontFamily: 'Inter', color: AppColors.foreground, height: 1.4)),
        if (latestBpSys != null || latestPulse != null || latestGlucose != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (latestBpSys != null && latestBpDia != null)
              _VitalChip(
                label: '${latestBpSys.value.toInt()}/${latestBpDia.value.toInt()}',
                unit: 'mmHg',
                icon: Icons.favorite_rounded,
                isNormal: VitalType.isNormal(VitalType.bpSystolic, latestBpSys.value) &&
                    VitalType.isNormal(VitalType.bpDiastolic, latestBpDia.value),
              ),
            if (latestPulse != null)
              _VitalChip(label: '${latestPulse.value.toInt()}', unit: 'bpm', icon: Icons.show_chart_rounded, isNormal: VitalType.isNormal(VitalType.pulse, latestPulse.value)),
            if (latestGlucose != null)
              _VitalChip(label: '${latestGlucose.value.toInt()}', unit: 'mg/dL', icon: Icons.water_drop_rounded, isNormal: VitalType.isNormal(VitalType.glucose, latestGlucose.value)),
          ]),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.go('/vitals'),
          child: Row(children: [
            const Icon(Icons.add_rounded, size: 14, color: AppColors.mutedForeground),
            const SizedBox(width: 4),
            Text(
              readings.isEmpty ? 'Log your first vital reading' : 'Update vitals',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter', decoration: TextDecoration.underline),
            ),
          ]),
        ),
      ]),
    );
  }

  String _interpret(VitalReading? bpSys, VitalReading? bpDia, VitalReading? pulse, VitalReading? glucose) {
    if (bpSys == null && pulse == null && glucose == null) return 'No vitals logged yet — tap below to add your first reading.';
    final parts = <String>[];
    if (bpSys != null && bpDia != null) {
      final ok = VitalType.isNormal(VitalType.bpSystolic, bpSys.value) && VitalType.isNormal(VitalType.bpDiastolic, bpDia.value);
      parts.add(ok ? 'Blood pressure is within normal range (${bpSys.value.toInt()}/${bpDia.value.toInt()} mmHg)' : bpSys.value > 120 ? 'Blood pressure is slightly elevated (${bpSys.value.toInt()}/${bpDia.value.toInt()} mmHg)' : 'Blood pressure is low (${bpSys.value.toInt()}/${bpDia.value.toInt()} mmHg)');
    }
    if (glucose != null && !VitalType.isNormal(VitalType.glucose, glucose.value)) {
      parts.add('glucose is ${glucose.value > 140 ? "above target" : "low"} (${glucose.value.toInt()} mg/dL)');
    }
    if (pulse != null && !VitalType.isNormal(VitalType.pulse, pulse.value)) {
      parts.add('pulse is ${pulse.value > 100 ? "elevated" : "low"} (${pulse.value.toInt()} bpm)');
    }
    if (parts.isEmpty) return 'Vitals are looking good — keep it up!';
    final first = parts.first[0].toUpperCase() + parts.first.substring(1);
    return parts.length > 1 ? '$first and ${parts.sublist(1).join(', ')}.' : '$first.';
  }
}

// ── Vital chip (color + shape) ────────────────────────────────────────────────
class _VitalChip extends StatelessWidget {
  final String label, unit;
  final IconData icon;
  final bool isNormal;
  const _VitalChip({required this.label, required this.unit, required this.icon, required this.isNormal});

  @override
  Widget build(BuildContext context) {
    final color = isNormal ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
        const SizedBox(width: 3),
        Text(unit, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter')),
        const SizedBox(width: 5),
        Icon(isNormal ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 11, color: color),
      ]),
    );
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
        child: _SnapshotChip(icon: Icons.medication_rounded, value: active.isEmpty ? '--' : '$taken/${active.length}', label: 'medicines', color: medColor),
      )),
      const SizedBox(width: 8),
      Expanded(child: _SnapshotChip(icon: Icons.local_fire_department_rounded, value: '${medStreak ?? 0}', label: 'day streak', color: streakColor)),
      const SizedBox(width: 8),
      Expanded(child: GestureDetector(
        onTap: () => context.go('/appointments'),
        child: _SnapshotChip(
          icon: Icons.calendar_today_rounded,
          value: daysToAppt == null ? '--' : daysToAppt == 0 ? 'today' : '${daysToAppt}d',
          label: 'next visit',
          color: visitColor,
        ),
      )),
    ]);
  }
}

class _SnapshotChip extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _SnapshotChip({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter'), textAlign: TextAlign.center),
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
class _EmergencyContactsStrip extends ConsumerWidget {
  final String uid;
  final AsyncValue<List<Appointment>> apptsAsync;
  const _EmergencyContactsStrip({required this.uid, required this.apptsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(patientCaregiverConnectionsProvider(uid)).asData?.value ?? [];
    final connected = connections.where((c) => c.status == 'connected').toList();

    final appts = apptsAsync.asData?.value ?? [];
    final recentDoctor = appts.where((a) => a.doctorName.isNotEmpty).firstOrNull;

    final hasDoctor = recentDoctor != null;
    final hasCaregiver = connected.isNotEmpty;
    if (!hasDoctor && !hasCaregiver) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.emergency_rounded, size: 13, color: AppColors.destructive),
        SizedBox(width: 6),
        Text('Quick Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground, fontFamily: 'Inter')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        if (hasDoctor) Expanded(
          child: GestureDetector(
            onTap: () => context.push('/my-doctors'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 20),
                const SizedBox(height: 5),
                Text(
                  recentDoctor.doctorName.split(' ').last,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Inter'),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text('Doctor', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            ),
          ),
        ),
        if (hasDoctor && hasCaregiver) const SizedBox(width: 10),
        if (hasCaregiver) Expanded(
          child: GestureDetector(
            onTap: () => context.push('/care-circle'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(height: 5),
                Text(
                  connected.first.caregiverName?.split(' ').first ?? 'Caregiver',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED), fontFamily: 'Inter'),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text('Caregiver', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ]),
            ),
          ),
        ),
      ]),
    ]);
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

    final dueMeds = meds.where((m) => m.isActive && (m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot)).toList();
    final missedMeds = meds.where((m) => m.isActive && m.hasMissedSlot && !m.hasDueSlot).toList();
    final upcomingMeals = _upcomingMeals(meals);
    final totalPending = dueMeds.length + upcomingMeals.length;

    final header = Row(children: [
      const Icon(Icons.checklist_rounded, size: 18),
      const SizedBox(width: 8),
      const Expanded(child: Text("Today's Tasks", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
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

    if (totalPending == 0 && missedMeds.isEmpty) {
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
      ...dueMeds.take(3).map((m) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TaskMedCard(medicine: m, uid: widget.uid))),
      if (dueMeds.length > 3)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => context.go('/care'),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Center(child: Text('+${dueMeds.length - 3} more — see all in Medicines', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontFamily: 'Inter', fontWeight: FontWeight.w500))),
            ),
          ),
        ),
      ...missedMeds.take(2).map((m) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TaskMedCard(medicine: m, uid: widget.uid, isMissed: true))),
      ...upcomingMeals.map((mealType) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _TaskMealCard(mealType: mealType, uid: widget.uid, onTap: () => showLogMealSheet(context, widget.uid, initialType: mealType)),
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

// ── Task Med Card ─────────────────────────────────────────────────────────────
class _TaskMedCard extends ConsumerWidget {
  final Medicine medicine;
  final String uid;
  final bool isMissed;
  const _TaskMedCard({required this.medicine, required this.uid, this.isMissed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = isMissed ? medicine.todaySlots.where((s) => s.isMissed).firstOrNull : medicine.nextPendingSlot;
    final subtitle = slot != null
        ? (isMissed ? 'Missed · ${slot.displayTime}' : '${medicine.dosage} · Due at ${slot.displayTime}')
        : '${medicine.dosage} · ${medicine.frequency}';

    final totalSlots = medicine.todaySlots.length;
    final takenSlots = medicine.todaySlots.where((s) => s.isTaken).length;
    final iconColor = isMissed ? AppColors.warning : AppColors.primary;
    final btnColor = isMissed ? AppColors.warning : AppColors.primary;
    final borderColor = isMissed ? AppColors.warning.withValues(alpha: 0.35) : AppColors.border;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.medication_rounded, color: iconColor, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(medicine.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
              if (totalSlots > 1) Container(
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+$hp HP  Dose logged!'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
              }
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: btnColor, borderRadius: BorderRadius.circular(10)),
              child: Text(isMissed ? 'Log' : 'Take', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Task Meal Card ────────────────────────────────────────────────────────────
class _TaskMealCard extends StatefulWidget {
  final String mealType, uid;
  final VoidCallback onTap;
  const _TaskMealCard({required this.mealType, required this.uid, required this.onTap});
  @override
  State<_TaskMealCard> createState() => _TaskMealCardState();
}

class _TaskMealCardState extends State<_TaskMealCard> {
  static const _defaults = {'Breakfast': '7:30 AM', 'Lunch': '12:30 PM', 'Dinner': '7:00 PM'};
  String? _timeHint;

  @override
  void initState() {
    super.initState();
    _loadTime();
  }

  Future<void> _loadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('meal_time_${widget.mealType.toLowerCase()}');
    if (mounted) setState(() => _timeHint = saved ?? _defaults[widget.mealType]);
  }

  @override
  Widget build(BuildContext context) {
    const mealIcons = {'Breakfast': Icons.wb_sunny_rounded, 'Lunch': Icons.light_mode_rounded, 'Dinner': Icons.nights_stay_rounded, 'Snack': Icons.cookie_rounded};
    final icon = mealIcons[widget.mealType] ?? Icons.restaurant_rounded;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.success, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Log your ${widget.mealType}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              Text(_timeHint != null ? 'Usual time · $_timeHint' : "Haven't logged this meal yet", style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
            ])),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
                child: const Text('Log Meal', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
            ),
          ]),
        ),
      ),
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
