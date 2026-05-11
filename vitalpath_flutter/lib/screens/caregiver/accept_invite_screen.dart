import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../models/caregiver_connection.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';

// C-6b: converted to StatefulWidget to hold _processing state
class AcceptInviteScreen extends ConsumerStatefulWidget {
  final CaregiverConnection connection;
  const AcceptInviteScreen({super.key, required this.connection});

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(inviteResponseNotifierProvider.notifier);
    final connection = widget.connection;

    // C-6: check invite status before allowing accept/decline
    final isAlreadyActioned = connection.status != 'pending';

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
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
                        color: AppColors.primary),
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
                            fontWeight: FontWeight.w700)),
                    Text(
                        'Invites you as ${connection.relationship.relationshipLabel}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ]),

            if (connection.personalMessage != null) ...[
              const SizedBox(height: 20),
              BentoCard(
                color: AppColors.muted,
                child: Text(
                  '"${connection.personalMessage}"',
                  style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.mutedForeground),
                ),
              ),
            ],

            const SizedBox(height: 28),
            const Text('If you accept, you will be able to see:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _permissionList(connection.permissions),

            const SizedBox(height: 20),
            BentoCard(
              color: AppColors.muted,
              child: const Text(
                'You will not be able to edit any health data.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground),
              ),
            ),

            const Spacer(),

            // C-6: show status message if already actioned
            if (isAlreadyActioned) ...[
              BentoCard(
                child: Text(
                  'This invite has already been ${connection.status}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedForeground),
                ),
              ),
            ] else if (_processing)
              const Center(child: CircularProgressIndicator())
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // C-6b: try/catch with error snackbar; navigate only on success
                  onPressed: () async {
                    setState(() => _processing = true);
                    try {
                      final user = await ref.read(currentUserProvider.future);
                      if (user == null) {
                        if (mounted) setState(() => _processing = false);
                        return;
                      }
                      await notifier.accept(
                        connectionId: connection.id,
                        caregiverUid: user.uid,
                        caregiverName: user.name,
                      );
                      if (context.mounted) context.go('/home');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Failed to accept invite. Please try again.')));
                      }
                    } finally {
                      if (mounted) setState(() => _processing = false);
                    }
                  },
                  child: const Text('Accept Invite',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  // C-6b: try/catch with error snackbar; navigate only on success
                  onPressed: () async {
                    setState(() => _processing = true);
                    try {
                      await notifier.decline(connection.id);
                      if (context.mounted) context.go('/home');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Failed to decline invite. Please try again.')));
                      }
                    } finally {
                      if (mounted) setState(() => _processing = false);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: const BorderSide(color: AppColors.destructive)),
                  child: const Text('Decline',
                      style: TextStyle(fontSize: 15)),
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
                Text(i.$3, style: const TextStyle(fontSize: 14)),
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
