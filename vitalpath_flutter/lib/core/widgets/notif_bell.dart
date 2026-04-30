import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../theme/app_theme.dart';

/// Notification bell icon for AppBars — shows an unread dot when there are
/// unread notifications. Safe to drop into any ConsumerWidget's `actions`.
class NotifBell extends ConsumerWidget {
  const NotifBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider).asData?.value?.uid;
    if (uid == null) return const SizedBox.shrink();
    final count = ref
        .watch(notificationsProvider(uid))
        .asData
        ?.value
        .where((n) => !n.isRead)
        .length ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
        if (count > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.destructive,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
