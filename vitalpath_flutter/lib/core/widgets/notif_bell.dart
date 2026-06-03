import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../theme/app_theme.dart';

/// Notification bell icon for AppBars — shows an unread dot when there are
/// unread notifications. Safe to drop into any ConsumerWidget's `actions`.
class NotifBell extends ConsumerWidget {
  const NotifBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();
    if (user.userType != UserType.patient) return const SizedBox.shrink();
    final uid = user.uid;
    final count = ref
            .watch(notificationsProvider(uid))
            .asData
            ?.value
            .where((n) => !n.isRead)
            .length ??
        0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedBellDot,
              color: Colors.black,
              size: 24),
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              constraints:
                  const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.destructive,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
