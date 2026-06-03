import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/app_notification.dart';
import '../../../models/caregiver_connection.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/caregiver_provider.dart';
import '../../../providers/patient_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
          body: Center(
              child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Something went wrong',
                  subtitle: 'Pull to refresh or try again.'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) {
              if (context.mounted) context.go('/user-select');
            },
          );
          return const Scaffold(body: SizedBox.shrink());
        }

        final notifsAsync = ref.watch(notificationsProvider(user.uid));
        final unread =
            notifsAsync.asData?.value.where((n) => !n.isRead).length ?? 0;

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unread > 0)
                TextButton(
                  onPressed: _markingAll
                      ? null
                      : () async {
                          setState(() => _markingAll = true);
                          try {
                            await ref
                                .read(notificationNotifierProvider.notifier)
                                .markAllRead(user.uid);
                          } catch (_) {
                            if (mounted) {
                              AppSnackBar.error(context,
                                  'Failed to mark notifications read');
                            }
                          } finally {
                            if (mounted) setState(() => _markingAll = false);
                          }
                        },
                  child: _markingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Mark all read',
                          style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          body: notifsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                subtitle: 'Pull to refresh or try again.'),
            data: (notifs) {
              if (notifs.isEmpty) {
                return const EmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: 'No Notifications',
                  subtitle: 'Reminders and updates will appear here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _NotifCard(
                  notif: notifs[i],
                  onTap: () => _onNotifTap(user.uid, notifs[i]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onNotifTap(String userUid, AppNotification notif) async {
    // Mark read on every tap.
    unawaited(
      ref.read(notificationNotifierProvider.notifier).markRead(userUid, notif.id),
    );
    // Open the quick-grant sheet for permission requests with a payload.
    if (notif.type == NotificationType.permissionRequest) {
      final connectionId = notif.data?['connectionId'] as String?;
      final section = notif.data?['section'] as String?;
      if (connectionId != null && section != null) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _PermissionGrantSheet(
            connectionId: connectionId,
            section: section,
          ),
        );
      }
      // No navigation for permission requests — user stays in sheet interaction
      return;
    }

    // Navigate based on notification type
    switch (notif.type) {
      case NotificationType.appointment:
        context.push('/appointments');
      case NotificationType.medicineReminder:
        context.push('/care');
      case NotificationType.mealReminder:
        context.push('/care');
      case NotificationType.general:
        // No navigation for general notifications
        break;
      case NotificationType.permissionRequest:
        // Already handled above
        break;
    }
  }
}

// ── Permission grant sheet ────────────────────────────────────────────────────
// Opened when the patient taps a permission_request notification.
// Loads the connection, shows the requesting family member + section,
// and offers a one-tap "Grant access" action.

class _PermissionGrantSheet extends ConsumerStatefulWidget {
  final String connectionId;
  final String section;
  const _PermissionGrantSheet({
    required this.connectionId,
    required this.section,
  });

  @override
  ConsumerState<_PermissionGrantSheet> createState() =>
      _PermissionGrantSheetState();
}

class _PermissionGrantSheetState extends ConsumerState<_PermissionGrantSheet> {
  CaregiverConnection? _conn;
  bool _loading = true;
  bool _granting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('caregiver_connections')
          .doc(widget.connectionId)
          .get();
      if (!mounted) return;
      if (!doc.exists || (doc.data()?['status'] as String?) == 'removed') {
        setState(() {
          _loading = false;
          _conn = null;
        });
        return;
      }
      setState(() {
        _conn = CaregiverConnection.fromDoc(doc);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load this request.';
      });
    }
  }

  Future<void> _grant() async {
    final conn = _conn;
    if (conn == null || _granting) return;
    setState(() => _granting = true);
    try {
      final newPerms = _grantSection(conn.permissions, widget.section);
      await ref.read(caregiverConnectionNotifierProvider.notifier).updatePermissions(
            connectionId: conn.id,
            patientId: conn.patientId,
            caregiverUid: conn.caregiverUid,
            permissions: newPerms,
          );
      if (mounted) {
        AppSnackBar.success(
            context, 'Access granted to ${conn.caregiverName ?? "your family member"}.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _granting = false);
        AppSnackBar.error(context, 'Failed to grant access. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_loadError != null)
              _SheetMessage(message: _loadError!)
            else if (_conn == null)
              const _SheetMessage(
                  message:
                      'This family member is no longer in your circle.')
            else if (_isGranted(_conn!.permissions, widget.section))
              _AlreadyGrantedBody(
                  name: _conn!.caregiverName ?? _conn!.caregiverEmail,
                  section: widget.section)
            else
              _GrantBody(
                name: _conn!.caregiverName ?? _conn!.caregiverEmail,
                section: widget.section,
                granting: _granting,
                onGrant: _grant,
              ),
          ],
        ),
      ),
    );
  }
}

class _GrantBody extends StatelessWidget {
  final String name;
  final String section;
  final bool granting;
  final VoidCallback onGrant;
  const _GrantBody({
    required this.name,
    required this.section,
    required this.granting,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_open_rounded,
                color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name wants access',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          'They\'ve asked to see your ${_sectionLabel(section)}. You can change this anytime in Care Circle.',
          style: const TextStyle(
              fontSize: 14, color: AppColors.mutedForeground, height: 1.4),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: granting ? null : onGrant,
          child: granting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('Grant access to ${_sectionLabel(section)}'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: granting ? null : () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
      ],
    );
  }
}

class _AlreadyGrantedBody extends StatelessWidget {
  final String name;
  final String section;
  const _AlreadyGrantedBody({required this.name, required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                color: AppColors.success,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Already granted',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          '$name already has access to your ${_sectionLabel(section)}.',
          style: const TextStyle(
              fontSize: 14, color: AppColors.mutedForeground, height: 1.4),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _SheetMessage extends StatelessWidget {
  final String message;
  const _SheetMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.mutedForeground)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

bool _isGranted(CaregiverPermissions p, String section) => switch (section) {
      'medicines' => p.medicines,
      'vitals' => p.vitals,
      'appointments' => p.appointments,
      'prescriptions' => p.prescriptions,
      'mealLogs' => p.mealLogs,
      'activityLogs' => p.activityLogs,
      _ => false,
    };

CaregiverPermissions _grantSection(CaregiverPermissions p, String section) =>
    switch (section) {
      'medicines' => p.copyWith(medicines: true),
      'vitals' => p.copyWith(vitals: true),
      'appointments' => p.copyWith(appointments: true),
      'prescriptions' => p.copyWith(prescriptions: true),
      'mealLogs' => p.copyWith(mealLogs: true),
      'activityLogs' => p.copyWith(activityLogs: true),
      _ => p,
    };

String _sectionLabel(String section) => switch (section) {
      'medicines' => 'medicines',
      'vitals' => 'vitals',
      'appointments' => 'appointments',
      'prescriptions' => 'prescriptions',
      'mealLogs' => 'meal logs',
      'activityLogs' => 'activity logs',
      _ => section,
    };

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  Widget _iconWidget(Color c) => switch (notif.type) {
        NotificationType.medicineReminder =>
          HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: c, size: 20),
        NotificationType.mealReminder =>
          Icon(Icons.restaurant_rounded, color: c, size: 20),
        NotificationType.appointment =>
          Icon(Icons.calendar_month_rounded, color: c, size: 20),
        NotificationType.permissionRequest =>
          Icon(Icons.lock_open_rounded, color: c, size: 20),
        NotificationType.general =>
          Icon(Icons.notifications_rounded, color: c, size: 20),
      };

  Color get _color => switch (notif.type) {
        NotificationType.medicineReminder => AppColors.primary,
        NotificationType.mealReminder => AppColors.warning,
        NotificationType.appointment => AppColors.primary,
        NotificationType.permissionRequest => AppColors.warning,
        NotificationType.general => AppColors.mutedForeground,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              notif.isRead ? AppColors.surface : _color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.isRead
                ? AppColors.border
                : _color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _iconWidget(_color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              notif.isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: _color, shape: BoxShape.circle),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(notif.body,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedForeground)),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notif.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(local);
  }
}
