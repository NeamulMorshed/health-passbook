import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/app_notification.dart';
import '../../../models/appointment.dart';
import '../../../models/caregiver_connection.dart';
import '../../../models/meal.dart';
import '../../../models/medicine.dart';
import '../../../models/prescription.dart';
import '../../../models/vital_reading.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/vitals_provider.dart';

part '_cg_profile_date_strip.dart';
part '_cg_profile_sections.dart';
part '_cg_profile_nudge.dart';

// ── Local provider: meals for an arbitrary date (caregiver view only) ─────────

typedef _MealsKey = ({String patientId, DateTime date});

final _cgMealsProvider =
    StreamProvider.family<List<MealLog>, _MealsKey>((ref, key) {
  final start = DateTime(key.date.year, key.date.month, key.date.day);
  final end = start.add(const Duration(days: 1));
  return FirebaseFirestore.instance
      .collection(AppConstants.colPatients)
      .doc(key.patientId)
      .collection(AppConstants.colMeals)
      .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('loggedAt', isLessThan: Timestamp.fromDate(end))
      .orderBy('loggedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => MealLog.fromMap(d.data(), d.id)).toList());
});

// ── Accent colours — warm amber, distinct from doctor (primary blue) ──────────

const _kAmber = AppColors.caregiver;
const _kAmberDark = AppColors.warning;

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CaregiverPatientProfileScreen extends ConsumerStatefulWidget {
  final CaregiverConnection connection;
  const CaregiverPatientProfileScreen({super.key, required this.connection});

  @override
  ConsumerState<CaregiverPatientProfileScreen> createState() =>
      _CaregiverPatientProfileScreenState();
}

class _CaregiverPatientProfileScreenState
    extends ConsumerState<CaregiverPatientProfileScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _showNudgeSheet(BuildContext context) {
    final conn = widget.connection;
    final caregiverUid = ref.read(currentUserProvider).asData?.value?.uid;
    if (caregiverUid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NudgeSheet(
        patientName: conn.patientName,
        caregiverUid: caregiverUid,
        onSend: (message) async {
          await _sendNudge(message);
          if (context.mounted) {
            AppSnackBar.success(context, 'Nudge sent to ${conn.patientName}');
          }
        },
      ),
    );
  }

  Future<void> _sendNudge(String message) async {
    final conn = widget.connection;
    final senderName = ref.read(currentUserProvider).asData?.value?.name ??
        'Your family member';
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    batch.set(
      db
          .collection('users')
          .doc(conn.patientId)
          .collection(AppConstants.colNotifications)
          .doc(),
      {
        'title': 'Family Care',
        'body': message,
        'type': 'nudge',
        'fromName': senderName,
        'fromUid': conn.caregiverUid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    // Mirror nudge timestamp on the caregiver mirror doc so _NudgeFollowUp
    // can compare against loggedDoses without reading patient notifications
    // (which caregivers cannot read by Firestore rule).
    if (conn.caregiverUid != null) {
      batch.update(
        db
            .collection('patients')
            .doc(conn.patientId)
            .collection('caregivers')
            .doc(conn.caregiverUid!),
        {
          'lastNudgeSentAt': FieldValue.serverTimestamp(),
          'lastNudgeMessage': message,
        },
      );
    }

    await batch.commit();
  }

  bool get _isToday {
    final t = _dateOnly(DateTime.now());
    return _selectedDate == t;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final conn = widget.connection;
    final p = conn.permissions;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNudgeSheet(context),
        backgroundColor: _kAmber,
        foregroundColor: Colors.white,
        icon: HugeIcon(
            icon: HugeIcons.strokeRoundedSent, color: Colors.white, size: 18),
        label: const Text('Send a nudge',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Warm amber header — intentionally different from doctor portal ──
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: _kAmber,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(64, 0, 16, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conn.patientName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(conn.relationship.relationshipLabel,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kAmber, _kAmberDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: const Alignment(-0.82, 0.4),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(conn.patientName),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Date strip ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DateStrip(
              selected: _selectedDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                'Tap a date to review that day\'s health activity',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
          ),

          // ── Dashboard ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Date label
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _isToday
                        ? 'Today — ${DateFormat('EEEE, MMMM d').format(_selectedDate)}'
                        : DateFormat('EEEE, MMMM d').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isToday ? _kAmber : AppColors.mutedForeground,
                    ),
                  ),
                ),

                if (p.medicines) ...[
                  if (conn.caregiverUid != null)
                    _NudgeFollowUp(
                      patientId: conn.patientId,
                      caregiverUid: conn.caregiverUid!,
                      patientName: conn.patientName,
                    ),
                  _MissedDoseNudge(patientId: conn.patientId),
                  _MedicinesSection(
                      patientId: conn.patientId, selectedDate: _selectedDate),
                ] else
                  _LockedSection(
                    icon: HugeIcons.strokeRoundedMedicine01,
                    title: 'Medicines',
                    patientName: conn.patientName,
                    section: 'medicines',
                    connectionId: conn.id,
                    patientUid: conn.patientId,
                    caregiverName:
                        conn.caregiverName ?? 'Your family member',
                  ),
                const SizedBox(height: 18),

                if (p.appointments) ...[
                  _AppointmentSection(patientId: conn.patientId),
                ] else
                  _LockedSection(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    title: 'Upcoming Visits',
                    patientName: conn.patientName,
                    section: 'appointments',
                    connectionId: conn.id,
                    patientUid: conn.patientId,
                    caregiverName:
                        conn.caregiverName ?? 'Your family member',
                  ),
                const SizedBox(height: 18),

                if (p.mealLogs) ...[
                  _MealsSection(
                      patientId: conn.patientId, selectedDate: _selectedDate),
                ] else
                  _LockedSection(
                    icon: HugeIcons.strokeRoundedRestaurant01,
                    title: 'Meals',
                    patientName: conn.patientName,
                    section: 'mealLogs',
                    connectionId: conn.id,
                    patientUid: conn.patientId,
                    caregiverName:
                        conn.caregiverName ?? 'Your family member',
                  ),
                const SizedBox(height: 18),

                if (p.vitals) ...[
                  _VitalsSection(patientId: conn.patientId),
                ] else
                  _LockedSection(
                    icon: HugeIcons.strokeRoundedPulse01,
                    title: 'Recent Readings',
                    patientName: conn.patientName,
                    section: 'vitals',
                    connectionId: conn.id,
                    patientUid: conn.patientId,
                    caregiverName:
                        conn.caregiverName ?? 'Your family member',
                  ),
                const SizedBox(height: 18),

                if (p.prescriptions) ...[
                  _PrescriptionsSection(patientId: conn.patientId),
                ] else
                  _LockedSection(
                    icon: HugeIcons.strokeRoundedMedicalFile,
                    title: 'Prescriptions',
                    patientName: conn.patientName,
                    section: 'prescriptions',
                    connectionId: conn.id,
                    patientUid: conn.patientId,
                    caregiverName:
                        conn.caregiverName ?? 'Your family member',
                  ),
                const SizedBox(height: 18),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _kAmber),
        ),
      );
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile(this.message);
  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              size: 16,
              color: AppColors.destructive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.destructive)),
          ),
        ]),
      );
}

class _EmptyTile extends StatelessWidget {
  final String message;
  const _EmptyTile(this.message);
  @override
  Widget build(BuildContext context) => BentoCard(
        padding: const EdgeInsets.all(14),
        child: Text(message,
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
      );
}
