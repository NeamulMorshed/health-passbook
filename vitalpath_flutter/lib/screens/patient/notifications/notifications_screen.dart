import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/app_notification.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }

        final notifsAsync = ref.watch(notificationsProvider(user.uid));
        final unread = notifsAsync.asData?.value.where((n) => !n.isRead).length ?? 0;

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unread > 0)
                TextButton(
                  onPressed: _markingAll ? null : () async {
                    setState(() => _markingAll = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(notificationNotifierProvider.notifier).markAllRead(user.uid);
                    } catch (_) {
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Failed to mark notifications read')));
                      }
                    } finally {
                      if (mounted) setState(() => _markingAll = false);
                    }
                  },
                  child: _markingAll
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Mark all read', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          body: notifsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'),
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
                  onTap: () => ref.read(notificationNotifierProvider.notifier).markRead(user.uid, notifs[i].id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  Widget _iconWidget(Color c) => switch (notif.type) {
    NotificationType.medicineReminder => HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: c, size: 20),
    NotificationType.mealReminder     => Icon(Icons.restaurant_rounded, color: c, size: 20),
    NotificationType.appointment      => Icon(Icons.calendar_month_rounded, color: c, size: 20),
    NotificationType.general          => Icon(Icons.notifications_rounded, color: c, size: 20),
  };

  Color get _color => switch (notif.type) {
    NotificationType.medicineReminder => AppColors.primary,
    NotificationType.mealReminder     => AppColors.warning,
    NotificationType.appointment      => AppColors.primary,
    NotificationType.general          => AppColors.mutedForeground,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? AppColors.surface : _color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.isRead ? AppColors.border : _color.withValues(alpha: 0.25),
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
                          fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(notif.body, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notif.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
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
