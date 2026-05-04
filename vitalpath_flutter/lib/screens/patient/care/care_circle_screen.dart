import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/doctor.dart';
import '../../../models/family_member.dart';
import '../../../models/medicine.dart';
import '../../../models/patient.dart';
import 'add_family_member_screen.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(myDoctorsProvider(uid));
    final membersAsync = ref.watch(familyMembersProvider(uid));
    final patientAsync = ref.watch(patientProfileProvider(uid));

    final doctorCount =
        doctorsAsync.asData?.value.length ?? 0;
    final memberCount =
        membersAsync.asData?.value.length ?? 0;
    final totalPeople = doctorCount + memberCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Care Circle'),
        actions: [
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
                      color: AppColors.primary,
                      fontFamily: 'Inter'),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Intro banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.people_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Care Circle',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Inter')),
                      Text(
                        'Everyone involved in your health journey.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontFamily: 'Inter'),
                      ),
                    ]),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Doctors section ───────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.medical_services_rounded,
            title: 'My Doctors',
            count: doctorCount,
            color: AppColors.doctorPrimary,
            action: TextButton.icon(
              onPressed: () => context.push('/my-doctors'),
              icon: const Icon(Icons.search_rounded, size: 14),
              label: const Text('Find more',
                  style: TextStyle(fontSize: 12, fontFamily: 'Inter')),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.doctorPrimary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
          const SizedBox(height: 10),
          doctorsAsync.when(
            loading: () => const _ShimmerCard(),
            error: (_, __) => const SizedBox.shrink(),
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

          // ── Family members section ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.family_restroom_rounded,
            title: 'Family Members',
            count: memberCount,
            color: AppColors.primary,
            action: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddFamilyMemberScreen(uid: uid)),
              ),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Add',
                  style: TextStyle(fontSize: 12, fontFamily: 'Inter')),
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
            error: (_, __) => const SizedBox.shrink(),
            data: (members) {
              if (members.isEmpty) {
                return _EmptyCard(
                  icon: Icons.person_add_rounded,
                  message: 'No family members added yet.',
                  actionLabel: 'Add member',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddFamilyMemberScreen(uid: uid)),
                  ),
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

          // ── Emergency contact section ─────────────────────────────────────
          _SectionHeader(
            icon: Icons.emergency_rounded,
            title: 'Emergency Contact',
            color: AppColors.destructive,
          ),
          const SizedBox(height: 10),
          patientAsync.when(
            loading: () => const _ShimmerCard(),
            error: (_, __) => const SizedBox.shrink(),
            data: (patient) {
              final contact = patient?.emergencyContact;
              if (contact == null) {
                return _EmptyCard(
                  icon: Icons.add_call,
                  message: 'No emergency contact saved.',
                  actionLabel: 'Add in Profile',
                  onAction: () => context.push('/edit-profile'),
                );
              }
              return _EmergencyContactCard(contact: contact);
            },
          ),

          const SizedBox(height: 32),
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.doctorLight,
          backgroundImage: doctor.photoUrl != null
              ? NetworkImage(doctor.photoUrl!)
              : null,
          child: doctor.photoUrl == null
              ? Text(
                  doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.doctorPrimary,
                      fontFamily: 'Inter'),
                )
              : null,
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Dr. ${doctor.name}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter')),
                  if (doctor.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.doctorPrimary),
                  ],
                ]),
                if (doctor.specialty != null)
                  Text(doctor.specialty!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                          fontFamily: 'Inter')),
                if (doctor.hospital != null)
                  Text(doctor.hospital!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                          fontFamily: 'Inter')),
              ]),
        ),

        // Actions
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              size: 20, color: AppColors.mutedForeground),
          onSelected: (v) {
            if (v == 'book') {
              context.go('/appointments');
            } else if (v == 'remove') {
              _confirmRemove(context, ref);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'book',
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 16),
                SizedBox(width: 8),
                Text('Book Appointment',
                    style: TextStyle(fontFamily: 'Inter')),
              ]),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(children: [
                Icon(Icons.link_off_rounded,
                    size: 16, color: AppColors.destructive),
                SizedBox(width: 8),
                Text('Remove Connection',
                    style: TextStyle(
                        fontFamily: 'Inter', color: AppColors.destructive)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Doctor',
            style: TextStyle(fontFamily: 'Inter')),
        content: Text(
          'Remove Dr. ${doctor.name} from your care circle? You will lose access to their prescriptions.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref.read(connectionNotifierProvider.notifier).remove(uid, doctor.uid);
            },
            child: const Text('Remove'),
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
    final medsAsync = ref.watch(
        familyMemberMedicinesProvider((uid: uid, memberId: member.id)));
    final medCount = medsAsync.asData?.value.length ?? 0;
    final isLinked = member.profileType == 'linked';

    void openEdit() => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  AddFamilyMemberScreen(uid: uid, existing: member)),
        );

    return GestureDetector(
      onTap: () => _showMemberDetail(context, ref, medsAsync),
      onLongPress: openEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          // Avatar
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
                        color: AppColors.primary,
                        fontFamily: 'Inter'))
                : null,
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(member.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter')),
                    ),
                    const SizedBox(width: 6),
                    // Profile type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLinked
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : AppColors.muted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isLinked
                              ? const Color(0xFFF59E0B)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        isLinked ? 'Linked' : 'Dependent',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isLinked
                                ? const Color(0xFFF59E0B)
                                : AppColors.mutedForeground,
                            fontFamily: 'Inter'),
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
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: medCount > 0
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.muted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$medCount ${medCount == 1 ? 'medicine' : 'medicines'}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: medCount > 0
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          fontFamily: 'Inter'),
                    ),
                  ),
                ]),
          ),

          // Edit button (visible trailing icon)
          IconButton(
            tooltip: 'Edit member',
            icon: const Icon(Icons.edit_rounded,
                size: 18, color: AppColors.mutedForeground),
            onPressed: openEdit,
          ),
        ]),
      ),
    );
  }

  void _showMemberDetail(
      BuildContext context, WidgetRef ref, AsyncValue<List<Medicine>> medsAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MemberDetailSheet(member: member, medsAsync: medsAsync),
    );
  }
}

// ─── Family member detail sheet ───────────────────────────────────────────────
class _MemberDetailSheet extends StatelessWidget {
  final FamilyMember member;
  final AsyncValue<List<Medicine>> medsAsync;

  const _MemberDetailSheet(
      {required this.member, required this.medsAsync});

  @override
  Widget build(BuildContext context) {
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
            // Handle
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),

            // Member header
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
                            color: AppColors.primary,
                            fontFamily: 'Inter'))
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
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter')),
                      Text(
                        [
                          member.relationship,
                          if (member.age != null) '${member.age} years old',
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                            fontFamily: 'Inter'),
                      ),
                    ]),
              ),
            ]),

            const SizedBox(height: 16),

            // Connect a Doctor button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/my-doctors');
                },
                icon: const Icon(Icons.medical_services_rounded, size: 16),
                label: const Text('Connect a Doctor',
                    style: TextStyle(fontFamily: 'Inter')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.doctorPrimary,
                  side: const BorderSide(color: AppColors.doctorPrimary),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Medicines
            const Text('Medicines',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter')),
            const SizedBox(height: 10),

            medsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (meds) {
                if (meds.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('No medicines recorded yet.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                            fontFamily: 'Inter')),
                  );
                }
                return Column(
                  children: meds
                      .map((med) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                    Icons.medication_rounded,
                                    size: 14,
                                    color: AppColors.primary),
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
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter')),
                                      Text(
                                          '${med.dosage} · ${med.frequency}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.mutedForeground,
                                              fontFamily: 'Inter')),
                                    ]),
                              ),
                              if (med.takenToday)
                                StatusBadge.success('Taken')
                              else if (med.hasDueSlot)
                                StatusBadge.warning('Due')
                              else
                                StatusBadge.info('Upcoming'),
                            ]),
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // Go to Care screen hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To log doses or add medicines, open the Care tab and select ${member.name.split(' ').first} from the profile switcher.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontFamily: 'Inter'),
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

// ─── Emergency contact card ───────────────────────────────────────────────────
class _EmergencyContactCard extends StatelessWidget {
  final EmergencyContact contact;
  const _EmergencyContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.destructive.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.emergency_rounded,
              color: AppColors.destructive, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contact.relationship.isNotEmpty)
                  Text(
                    contact.relationship,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter'),
                  ),
                Text(
                  contact.name.isNotEmpty ? contact.name : contact.phone,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter'),
                ),
                if (contact.name.isNotEmpty && contact.phone.isNotEmpty)
                  Text(
                    contact.phone,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter'),
                  ),
              ]),
        ),
        IconButton(
          onPressed: contact.phone.isNotEmpty ? () => _call(contact.phone) : null,
          icon: const Icon(Icons.call_rounded, color: AppColors.success),
          tooltip: 'Call',
        ),
      ]),
    );
  }

  Future<void> _call(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
                color: color,
                fontFamily: 'Inter')),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFamily: 'Inter')),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter'))),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(actionLabel,
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    color: AppColors.primary)),
          ),
        ]),
      );
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
      );
}
