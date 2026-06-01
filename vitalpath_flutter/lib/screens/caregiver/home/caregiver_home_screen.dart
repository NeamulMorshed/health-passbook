import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../models/app_user.dart';
import '../../../models/medicine.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../models/caregiver_connection.dart';
import '../../../core/widgets/freshness_timestamp.dart';

final _caregiverLastRefreshedProvider =
    StateProvider<DateTime>((_) => DateTime.now());

class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(
            child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.',
        )),
      ),
      data: (user) {
        if (user == null || user.userType != UserType.caregiver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (user?.userType == UserType.doctor) {
              context.go('/doc/dashboard');
            } else if (user?.userType == UserType.patient) {
              context.go('/home');
            } else {
              context.go('/user-select');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return _HomeContent(user: user);
      },
    );
  }
}

// ── Home content ──────────────────────────────────────────────────────────────

class _HomeContent extends ConsumerStatefulWidget {
  final AppUser user;
  const _HomeContent({required this.user});
  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent> {
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
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider(widget.user.uid));
    final connectedPatientsAsync =
        ref.watch(caregiverPatientsProvider(widget.user.uid));
    final pendingInvitesAsync =
        ref.watch(pendingInvitesForEmailProvider(widget.user.email ?? ''));
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return membersAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(
            child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.',
        )),
      ),
      data: (members) {
        if (_selectedMemberId == null && members.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => setState(() => _selectedMemberId = members.first.id),
          );
        }
        final selectedMember =
            members.where((m) => m.id == _selectedMemberId).firstOrNull;

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
              Text(
                widget.user.name.isNotEmpty
                    ? widget.user.name
                    : 'Family Member',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground),
              ),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(today,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedForeground)),
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
              ref.read(_caregiverLastRefreshedProvider.notifier).state =
                  DateTime.now();
            },
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                sliver: SliverList(
                    delegate: SliverChildListDelegate([
                  FreshnessTimestamp(
                      lastUpdated:
                          ref.watch(_caregiverLastRefreshedProvider)),
                  const SizedBox(height: 12),

                  // ── Onboarding guidance (shown only when no connections yet) ──
                  if ((connectedPatientsAsync.asData?.value ?? []).isEmpty &&
                      (pendingInvitesAsync.asData?.value ?? []).isEmpty) ...[
                    _OnboardingGuidanceCard(),
                    const SizedBox(height: 16),
                  ],

                  // ── Pending invite banners ────────────────────────────────
                  ...((pendingInvitesAsync.asData?.value ?? []).map((inv) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BentoCard(
                          color: AppColors.inviteAccent.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          onTap: () => context.go('/accept-invite', extra: inv),
                          child: Row(children: [
                            HugeIcon(
                                icon: HugeIcons.strokeRoundedShield01,
                                color: AppColors.inviteAccent,
                                size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                              '${inv.patientName} wants to share their health with you (as your ${inv.relationship.relationshipLabel})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            )),
                            HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                color: AppColors.inviteAccent,
                                size: 16),
                          ]),
                        ),
                      ))),

                  // ── Connected patients ────────────────────────────────────
                  ...((connectedPatientsAsync.asData?.value ?? []).isNotEmpty
                      ? [
                          const Text('Connected Family',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mutedForeground)),
                          const SizedBox(height: 10),
                          ...((connectedPatientsAsync.asData?.value ?? [])
                              .map((conn) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: BentoCard(
                                      onTap: () => context.go(
                                          '/caregiver-patient-profile',
                                          extra: conn),
                                      child: Row(children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppColors
                                              .inviteAccent
                                              .withValues(alpha: 0.12),
                                          child: Text(
                                              _initials(conn.patientName),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.inviteAccent)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(conn.patientName,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              Text(
                                                  conn.relationship
                                                      .relationshipLabel,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .mutedForeground)),
                                            ])),
                                        HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedArrowRight01,
                                            color: AppColors.textTertiary,
                                            size: 16),
                                      ]),
                                    ),
                                  ))),
                          const SizedBox(height: 12),
                        ]
                      : []),

                  // ── Family member selector ────────────────────────────────
                  const Text('Who are you looking after today?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground)),
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
                            onTap: () =>
                                setState(() => _selectedMemberId = m.id),
                            child: Column(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? AppColors.caregiver
                                      : AppColors.caregiver
                                          .withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.caregiver
                                        : AppColors.border,
                                    width: selected ? 2.5 : 1,
                                  ),
                                ),
                                child: Center(
                                    child: Text(m.initials,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.caregiver,
                                        ))),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 60,
                                child: Text(m.name.split(' ').first,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: selected
                                          ? AppColors.caregiver
                                          : AppColors.mutedForeground,
                                    )),
                              ),
                            ]),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Selected member overview ──────────────────────────────
                  if (selectedMember != null) ...[
                    _DailySummaryBanner(
                      caregiverUid: widget.user.uid,
                      memberId: selectedMember.id,
                      memberName: selectedMember.name,
                      memberInitials: selectedMember.initials,
                      memberAge: selectedMember.age,
                      memberRelationship: selectedMember.relationship,
                    ),
                    const SizedBox(height: 12),
                    _MedSection(
                      caregiverUid: widget.user.uid,
                      memberId: selectedMember.id,
                      memberName: selectedMember.name,
                    ),
                    const SizedBox(height: 12),
                    _QuickActions(
                        caregiverUid: widget.user.uid,
                        memberId: selectedMember.id),
                  ] else if (members.isNotEmpty)
                    const Center(child: CircularProgressIndicator()),

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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyMembersCard extends StatelessWidget {
  final String caregiverUid;
  const _EmptyMembersCard({required this.caregiverUid});

  @override
  Widget build(BuildContext context) => BentoCard(
        child: Column(children: [
          const SizedBox(height: 4),
          HugeIcon(
              icon: HugeIcons.strokeRoundedGroup,
              color: AppColors.caregiver,
              size: 36),
          const SizedBox(height: 10),
          const Text('No family members yet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Go to Family to add the people you look after.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => context.go('/caregiver/patients'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.caregiver),
              foregroundColor: AppColors.caregiver,
            ),
            child: const Text('Go to Family',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
        ]),
      );
}

// ── Onboarding guidance card ──────────────────────────────────────────────────

class _OnboardingGuidanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.caregiver.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.caregiver.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            HugeIcon(
                icon: HugeIcons.strokeRoundedHeartCheck,
                color: AppColors.caregiver,
                size: 22),
            const SizedBox(width: 10),
            const Text('Welcome to Family Care',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.caregiver)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'This portal is for family members who look after their loved ones. You can monitor medicines, meals, vitals, and appointments for your family.',
            style: TextStyle(
                fontSize: 13, color: AppColors.foreground, height: 1.4),
          ),
          const SizedBox(height: 12),
          _GuidanceStep(
              icon: HugeIcons.strokeRoundedMail01,
              label: 'Wait for a family member to invite you, or'),
          const SizedBox(height: 6),
          _GuidanceStep(
              icon: HugeIcons.strokeRoundedUserAdd01,
              label: 'Ask them to invite you from their Health Circle'),
        ]),
      );
}

class _GuidanceStep extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  const _GuidanceStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 14, color: AppColors.caregiver),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground))),
        ],
      );
}

// ── Medicine section ──────────────────────────────────────────────────────────

class _MedSection extends ConsumerWidget {
  final String caregiverUid, memberId, memberName;
  const _MedSection(
      {required this.caregiverUid,
      required this.memberId,
      required this.memberName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(
        familyMemberMedicinesProvider((uid: caregiverUid, memberId: memberId)));
    return medsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (meds) {
        final activeMeds = meds.where((m) => m.isActive).toList();
        final takenToday = activeMeds.where((m) => m.takenToday).length;
        final dueMeds = activeMeds
            .where((m) =>
                m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot)
            .toList();

        final dueColor =
            dueMeds.isNotEmpty ? AppColors.warning : AppColors.success;
        final dueIcon = dueMeds.isNotEmpty
            ? HugeIcons.strokeRoundedAlarmClock
            : HugeIcons.strokeRoundedCheckmarkCircle01;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BentoCard(
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.caregiverLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                      icon: HugeIcons.strokeRoundedMedicine01,
                      color: AppColors.caregiver,
                      size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '$takenToday/${activeMeds.length}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const Text('taken today',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '${dueMeds.length}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: dueColor),
                ),
                Text(
                  dueMeds.isNotEmpty ? 'due now' : 'all done',
                  style: TextStyle(fontSize: 12, color: dueColor),
                ),
              ]),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: dueColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: HugeIcon(icon: dueIcon, color: dueColor, size: 18)),
              ),
            ]),
          ),
          if (activeMeds.isEmpty) ...[
            const SizedBox(height: 12),
            BentoCard(
              child: Column(children: [
                const SizedBox(height: 8),
                HugeIcon(
                    icon: HugeIcons.strokeRoundedMedicine01,
                    color: AppColors.mutedForeground,
                    size: 28),
                const SizedBox(height: 8),
                Text('No medicines for $memberName yet',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.mutedForeground)),
                const SizedBox(height: 8),
              ]),
            ),
          ] else if (dueMeds.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Due now',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...dueMeds.take(3).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MedTile(
                      medicine: m,
                      caregiverUid: caregiverUid,
                      memberId: memberId,
                      memberName: memberName),
                )),
            if (dueMeds.length > 3)
              BentoCard(
                onTap: () => context.go('/caregiver/patients'),
                child: Center(
                    child: Text(
                  '+${dueMeds.length - 3} more — see all in Family',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500),
                )),
              ),
          ] else ...[
            const SizedBox(height: 12),
            BentoCard(
              color: AppColors.successLight,
              child: Column(children: [
                const SizedBox(height: 4),
                HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    color: AppColors.success,
                    size: 28),
                const SizedBox(height: 6),
                const Text('All medicines taken!',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success)),
                const SizedBox(height: 4),
              ]),
            ),
          ],
        ]);
      },
    );
  }
}

class _MedTile extends ConsumerWidget {
  final Medicine medicine;
  final String caregiverUid, memberId, memberName;
  const _MedTile({
    required this.medicine,
    required this.caregiverUid,
    required this.memberId,
    required this.memberName,
  });

  void _confirm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log dose for ${medicine.name}?',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                "This will update $memberName's health record.",
                style: const TextStyle(
                    fontSize: 13, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.caregiver),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref
                        .read(familyMedicinePatchProvider)
                        .logDose(caregiverUid, memberId, medicine.id);
                  },
                  child: const Text('Log as Taken'),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = medicine.nextPendingSlot;
    final subtitle = slot != null
        ? '${medicine.dosage} · Due at ${slot.displayTime}'
        : '${medicine.dosage} · ${medicine.frequency}';

    return BentoCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.caregiver.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: HugeIcon(
              icon: HugeIcons.strokeRoundedMedicine01,
              color: AppColors.caregiver,
              size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(medicine.name,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _confirm(context, ref),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.caregiver,
                borderRadius: BorderRadius.circular(10)),
            child: const Text('Log as Taken',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final String caregiverUid, memberId;
  const _QuickActions({required this.caregiverUid, required this.memberId});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BentoSectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _ActionBtn(
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedMedicine01,
                color: AppColors.caregiver,
                size: 22),
            label: 'Check Medicines',
            color: AppColors.caregiver,
            onTap: () => context.go('/caregiver/patients'),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _ActionBtn(
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar01,
                color: AppColors.info,
                size: 22),
            label: 'Appointments',
            color: AppColors.info,
            onTap: () => context.go('/caregiver/patients'),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _ActionBtn(
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedUser,
                color: AppColors.mutedForeground,
                size: 22),
            label: 'My Profile',
            color: AppColors.mutedForeground,
            onTap: () => context.go('/caregiver/profile'),
          )),
        ]),
      ]);
}

class _ActionBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

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
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

// ── Daily summary banner ──────────────────────────────────────────────────────

class _DailySummaryBanner extends ConsumerWidget {
  final String caregiverUid;
  final String memberId;
  final String memberName;
  final String memberInitials;
  final int? memberAge;
  final String memberRelationship;

  const _DailySummaryBanner({
    required this.caregiverUid,
    required this.memberId,
    required this.memberName,
    required this.memberInitials,
    required this.memberAge,
    required this.memberRelationship,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(
      familyMemberMedicinesProvider((uid: caregiverUid, memberId: memberId)),
    );

    final meds = medsAsync.asData?.value;

    final String statusText;
    final Color statusColor;
    final List<List<dynamic>> statusIcon;

    if (meds == null) {
      statusText =
          medsAsync.isLoading ? 'Loading today\'s status…' : 'Could not load';
      statusColor = AppColors.mutedForeground;
      statusIcon = HugeIcons.strokeRoundedClock01;
    } else {
      final active = meds.where((m) => m.isActive).toList();
      if (active.isEmpty) {
        statusText = 'No medicines scheduled today';
        statusColor = AppColors.mutedForeground;
        statusIcon = HugeIcons.strokeRoundedCheckmarkCircle01;
      } else {
        final due = active
            .where((m) =>
                m.hasNoScheduledTimes ? !m.fullyTakenToday : m.hasDueSlot)
            .length;
        if (due == 0) {
          statusText = 'All caught up on medicines today';
          statusColor = AppColors.success;
          statusIcon = HugeIcons.strokeRoundedCheckmarkCircle01;
        } else {
          statusText = '$due medicine${due > 1 ? 's' : ''} to take today';
          statusColor = AppColors.caregiver;
          statusIcon = HugeIcons.strokeRoundedMedicine01;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.caregiver.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Text(
              memberInitials,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.caregiver),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              memberName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (memberAge != null)
              Text(
                '$memberAge yrs · $memberRelationship',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground),
              ),
            const SizedBox(height: 4),
            Row(children: [
              HugeIcon(icon: statusIcon, color: statusColor, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  statusText,
                  style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
