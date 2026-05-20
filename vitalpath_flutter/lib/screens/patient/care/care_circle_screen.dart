import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../models/doctor.dart';
import '../../../models/family_member.dart';
import '../../../models/caregiver_connection.dart';
import 'add_family_member_screen.dart';
import 'invite_caregiver_screen.dart';
import 'manage_caregiver_screen.dart';

class CareCircleScreen extends ConsumerWidget {
  const CareCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.',
        ),
      ),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) {
              if (context.mounted) context.go('/user-select');
            },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        return _CareCircleBody(uid: user.uid);
      },
    );
  }
}

class _CareCircleBody extends ConsumerWidget {
  final String uid;
  const _CareCircleBody({required this.uid});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myDoctorsProvider(uid));
    ref.invalidate(familyMembersProvider(uid));
    ref.invalidate(patientCaregiverConnectionsProvider(uid));
    // H-CC1: also await the caregiver connections future
    await Future.wait([
      ref.read(myDoctorsProvider(uid).future).catchError((_) => <DoctorProfile>[]),
      ref.read(familyMembersProvider(uid).future).catchError((_) => <FamilyMember>[]),
      ref.read(patientCaregiverConnectionsProvider(uid).future).catchError((_) => <CaregiverConnection>[]),
    ]);
  }

  Future<void> _openAddMember(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddFamilyMemberScreen(uid: uid)),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family member added')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(myDoctorsProvider(uid));
    final membersAsync = ref.watch(familyMembersProvider(uid));
    final caregiversAsync = ref.watch(patientCaregiverConnectionsProvider(uid));

    final doctorCount = doctorsAsync.asData?.value.length ?? 0;
    final memberCount = membersAsync.asData?.value.length ?? 0;
    final caregiverCount = caregiversAsync.asData?.value
        .where((c) => c.isConnected).length ?? 0;
    final totalPeople = doctorCount + memberCount + caregiverCount;
    final isLoading = doctorsAsync.isLoading || membersAsync.isLoading;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Health Circle'),
        actions: [
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalPeople ${totalPeople == 1 ? 'person' : 'people'}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Intro banner ────────────────────────────────────────────────
            BentoCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                HugeIcon(icon: HugeIcons.strokeRoundedGroup, color: AppColors.primary, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Health Circle',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground)),
                        Text(
                          isLoading
                              ? 'Everyone involved in your health journey.'
                              : [
                                  if (doctorCount > 0)
                                    '$doctorCount ${doctorCount == 1 ? 'doctor' : 'doctors'}',
                                  if (memberCount > 0)
                                    '$memberCount ${memberCount == 1 ? 'family member' : 'family members'}',
                                  if (caregiverCount > 0)
                                    '$caregiverCount ${caregiverCount == 1 ? 'family monitor' : 'family monitors'}',
                                ].isEmpty
                                  ? 'Add people to your health circle.'
                                  : [
                                      if (doctorCount > 0)
                                        '$doctorCount ${doctorCount == 1 ? 'doctor' : 'doctors'}',
                                      if (memberCount > 0)
                                        '$memberCount ${memberCount == 1 ? 'family member' : 'family members'}',
                                      if (caregiverCount > 0)
                                        '$caregiverCount ${caregiverCount == 1 ? 'family monitor' : 'family monitors'}',
                                    ].join(' · '),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground),
                        ),
                      ]),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Doctors section ─────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.medical_services_rounded,
              title: 'My Doctors',
              count: doctorsAsync.hasValue ? doctorCount : null,
              color: AppColors.primary,
              action: TextButton.icon(
                onPressed: () => context.push('/my-doctors'),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: Colors.black, size: 14),
                label: const Text('Find more',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ),
            const SizedBox(height: 10),
            doctorsAsync.when(
              loading: () => const _ShimmerCard(),
              error: (_, __) => _ErrorCard(
                message: 'Could not load doctors.',
                onRetry: () => ref.invalidate(myDoctorsProvider(uid)),
              ),
              data: (doctors) {
                if (doctors.isEmpty) {
                  return _EmptyCard(
                    icon: Icons.person_add_rounded,
                    message: 'No connected doctors yet.',
                    actionLabel: 'Find a doctor',
                    onAction: () => context.push('/my-doctors'),
                  );
                }
                return Column(
                  children: doctors
                      .map((d) => _DoctorCard(uid: uid, doctor: d))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Family members section ──────────────────────────────────────
            _SectionHeader(
              icon: Icons.family_restroom_rounded,
              title: 'Family Members',
              count: membersAsync.hasValue ? memberCount : null,
              color: AppColors.primary,
              action: TextButton.icon(
                onPressed: () => _openAddMember(context, ref),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: Colors.black, size: 14),
                label: const Text('Add',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ),
            const SizedBox(height: 10),
            membersAsync.when(
              loading: () => const _ShimmerCard(),
              error: (_, __) => _ErrorCard(
                message: 'Could not load family members.',
                onRetry: () => ref.invalidate(familyMembersProvider(uid)),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return _EmptyCard(
                    icon: Icons.person_add_rounded,
                    message: 'No family members added yet.',
                    actionLabel: 'Add member',
                    onAction: () => _openAddMember(context, ref),
                  );
                }
                return Column(
                  children: members
                      .map((m) => _FamilyMemberCard(uid: uid, member: m))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Caregivers / family viewers section ─────────────────────────
            // M-CC1: count only connected caregivers (not pending)
            _SectionHeader(
              icon: Icons.shield_rounded,
              title: 'Family Monitoring Me',
              count: caregiversAsync.hasValue
                  ? caregiversAsync.asData!.value
                      .where((c) => c.isConnected)
                      .length
                  : null,
              color: const Color(0xFF7C3AED),
              action: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InviteCaregiverScreen()),
                ),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: Colors.black, size: 14),
                label: const Text('Invite',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ),
            const SizedBox(height: 10),
            caregiversAsync.when(
              loading: () => const _ShimmerCard(),
              error: (_, __) => _ErrorCard(
                message: 'Could not load caregivers.',
                onRetry: () =>
                    ref.invalidate(patientCaregiverConnectionsProvider(uid)),
              ),
              data: (connections) {
                if (connections.isEmpty) {
                  return _EmptyCard(
                    icon: Icons.shield_outlined,
                    message:
                        'No family members monitoring you yet.\nInvite a family member to stay updated on your health.',
                    actionLabel: 'Invite family member',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InviteCaregiverScreen()),
                    ),
                  );
                }
                return Column(
                  children: connections
                      .map((c) => _CaregiverCard(connection: c))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Doctor card ──────────────────────────────────────────────────────────────
class _DoctorCard extends ConsumerWidget {
  final String uid;
  final DoctorProfile doctor;
  const _DoctorCard({required this.uid, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        onTap: () => _showDoctorDetail(context, ref),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.doctorLight,
            backgroundImage: doctor.photoUrl != null
                ? NetworkImage(doctor.photoUrl!)
                : null,
            child: doctor.photoUrl == null
                ? Text(
                    doctor.name.isNotEmpty
                        ? doctor.name[0].toUpperCase()
                        : 'D',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Dr. ${doctor.name}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (doctor.isVerified) ...[
                      const SizedBox(width: 4),
                      HugeIcon(icon: HugeIcons.strokeRoundedShieldKey, color: AppColors.primary, size: 14),
                    ],
                  ]),
                  if (doctor.specialty != null)
                    Text(doctor.specialty!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground)),
                  if (doctor.hospital != null)
                    Text(doctor.hospital!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground)),
                ]),
          ),
          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.mutedForeground, size: 14),
        ]),
      ),
    );
  }

  void _showDoctorDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.doctorLight,
                  backgroundImage: doctor.photoUrl != null
                      ? NetworkImage(doctor.photoUrl!)
                      : null,
                  child: doctor.photoUrl == null
                      ? Text(
                          doctor.name.isNotEmpty
                              ? doctor.name[0].toUpperCase()
                              : 'D',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Dr. ${doctor.name}',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          if (doctor.isVerified) ...[
                            const SizedBox(width: 4),
                            HugeIcon(icon: HugeIcons.strokeRoundedShieldKey, color: AppColors.primary, size: 15),
                          ],
                        ]),
                        if (doctor.specialty != null)
                          Text(doctor.specialty!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedForeground)),
                        if (doctor.hospital != null)
                          Text(doctor.hospital!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground)),
                      ]),
                ),
              ]),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/appointments');
                  },
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: Colors.black, size: 16),
                  label: const Text('Book Appointment'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmRemove(context, ref);
                  },
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedUnlink01, color: AppColors.destructive, size: 16),
                  label: const Text('Remove Connection',
                      style: TextStyle(
                          color: AppColors.destructive)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.destructive),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Doctor'),
        content: Text(
          'Remove Dr. ${doctor.name} from your care circle? You will lose access to their prescriptions.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  try {
                    await ref
                        .read(connectionNotifierProvider.notifier)
                        .remove(uid, doctor.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Doctor removed from your care circle.'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Failed to remove doctor. Please try again.'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
                child: const Text('Remove'),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Family member card ───────────────────────────────────────────────────────
class _FamilyMemberCard extends ConsumerWidget {
  final String uid;
  final FamilyMember member;
  const _FamilyMemberCard({required this.uid, required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLinked = member.profileType == 'linked';

    void openEdit() => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  AddFamilyMemberScreen(uid: uid, existing: member)),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        onTap: () => _showMemberDetail(context),
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: member.photoUrl != null
                ? NetworkImage(member.photoUrl!)
                : null,
            child: member.photoUrl == null
                ? Text(member.initials,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(member.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLinked
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : AppColors.muted,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLinked
                              ? const Color(0xFFF59E0B)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        isLinked ? 'Linked' : 'Dependent',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLinked
                                ? const Color(0xFFF59E0B)
                                : AppColors.mutedForeground),
                      ),
                    ),
                  ]),
                  Text(
                    [
                      member.relationship,
                      if (member.age != null) '${member.age} yrs',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'View details →',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedForeground),
                    ),
                  ),
                ]),
          ),
          IconButton(
            tooltip: 'Edit member',
            icon: HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit01, color: AppColors.mutedForeground, size: 18),
            onPressed: openEdit,
          ),
        ]),
      ),
    );
  }

  void _showMemberDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MemberDetailSheet(uid: uid, member: member),
    );
  }
}

// ─── Family member detail sheet ───────────────────────────────────────────────
class _MemberDetailSheet extends ConsumerWidget {
  final String uid;
  final FamilyMember member;

  const _MemberDetailSheet({required this.uid, required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(
        familyMemberMedicinesProvider((uid: uid, memberId: member.id)));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (sheetCtx, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),

            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: member.photoUrl != null
                    ? NetworkImage(member.photoUrl!)
                    : null,
                child: member.photoUrl == null
                    ? Text(member.initials,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text(
                        [
                          member.relationship,
                          if (member.age != null)
                            '${member.age} years old',
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground),
                      ),
                    ]),
              ),
            ]),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddFamilyMemberScreen(uid: uid, existing: member),
                    ),
                  );
                },
                icon: HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit01, color: Colors.black, size: 16),
                label: const Text('Edit member details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            const Text('Medicines',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            medsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => BentoCard(
                color: AppColors.muted,
                padding: const EdgeInsets.all(14),
                child: const Text('Could not load medicines.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground)),
              ),
              data: (meds) {
                if (meds.isEmpty) {
                  return BentoCard(
                    color: AppColors.muted,
                    padding: const EdgeInsets.all(14),
                    child: const Text('No medicines recorded yet.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground)),
                  );
                }
                return Column(
                  children: meds
                      .map((med) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: BentoCard(
                              color: AppColors.muted,
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.primary, size: 14),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(med.name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                            '${med.dosage} · ${med.frequency}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.mutedForeground)),
                                      ]),
                                ),
                                if (med.takenToday)
                                  StatusBadge.success('Taken')
                                else if (med.hasDueSlot)
                                  StatusBadge.warning('Due')
                                else
                                  StatusBadge.info('Upcoming'),
                              ]),
                            ),
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To log doses or add medicines, open the Care tab and select ${member.name.split(' ').first} from the profile switcher.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final int? count;
  final Widget? action;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.count,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color)),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ],
        const Spacer(),
        if (action != null) action!,
      ]);
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground))),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(actionLabel,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary)),
          ),
        ]),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 20, color: AppColors.destructive),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground))),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Retry',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary)),
          ),
        ]),
      );
}

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.muted.withValues(alpha: _anim.value),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
}

// ─── Caregiver card ───────────────────────────────────────────────────────────
class _CaregiverCard extends ConsumerWidget {
  final CaregiverConnection connection;
  const _CaregiverCard({required this.connection});

  static const _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // H-CC2: null-safe fallback for caregiver name/email
    final name = connection.caregiverName ?? connection.caregiverEmail;
    final initials = _initials(name);
    final isPending = connection.isPending;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        onTap: isPending
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageCaregiverScreen(connection: connection),
                  ),
                ),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _purple.withValues(alpha: 0.12),
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _purple)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(connection.relationship.relationshipLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground)),
                  if (!isPending)
                    Text(
                      'Connected ${connection.connectedAt != null ? DateFormat('MMM d, y').format(connection.connectedAt!) : ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground),
                    ),
                ]),
          ),
          if (isPending)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Pending',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning)),
          )
          else
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.mutedForeground, size: 14),
        ]),
      ),
    );
  }

  // H-CC2: safe initials computation
  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
