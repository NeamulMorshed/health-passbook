import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/caregiver_connection.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';

class AcceptInviteScreen extends ConsumerWidget {
  final CaregiverConnection connection;
  const AcceptInviteScreen({super.key, required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(inviteResponseNotifierProvider.notifier);
    final state = ref.watch(inviteResponseNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Care Circle Invite')),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient avatar + name
            Row(children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(connection.patientName),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'Inter'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(connection.patientName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter')),
                    Text(
                        'Invites you as ${connection.relationship.relationshipLabel}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                            fontFamily: 'Inter')),
                  ],
                ),
              ),
            ]),

            if (connection.personalMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"${connection.personalMessage}"',
                  style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter'),
                ),
              ),
            ],

            const SizedBox(height: 28),
            const Text('If you accept, you will be able to see:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter')),
            const SizedBox(height: 12),
            _permissionList(connection.permissions),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'You will not be able to edit any health data.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter'),
              ),
            ),

            const Spacer(),

            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final user = await ref.read(currentUserProvider.future);
                    if (user == null) return;
                    await notifier.accept(
                      connectionId: connection.id,
                      caregiverUid: user.uid,
                      caregiverName: user.name,
                    );
                    if (context.mounted) context.go('/home');
                  },
                  child: const Text('Accept Invite',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await notifier.decline(connection.id);
                    if (context.mounted) context.go('/home');
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: const BorderSide(color: AppColors.destructive)),
                  child: const Text('Decline',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15)),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _permissionList(CaregiverPermissions p) {
    final items = <(bool, IconData, String)>[
      (p.medicines, Icons.medication_rounded, 'Medicines & dose tracking'),
      (p.vitals, Icons.monitor_heart_rounded, 'Vitals & readings'),
      (p.appointments, Icons.calendar_today_rounded, 'Upcoming appointments'),
      (p.prescriptions, Icons.receipt_long_rounded, 'Prescriptions'),
      (p.mealLogs, Icons.restaurant_rounded, 'Meal logs'),
      (p.activityLogs, Icons.directions_run_rounded, 'Activity logs'),
    ];
    return Column(
      children: items
          .where((i) => i.$1)
          .map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(i.$2, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(i.$3,
                    style: const TextStyle(
                        fontSize: 14, fontFamily: 'Inter')),
              ]),
            ),
          )
          .toList(),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
