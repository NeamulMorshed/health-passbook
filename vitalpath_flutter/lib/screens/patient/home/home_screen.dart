import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/app_user.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (context.mounted) context.go('/user-select'); },
          );
          return const Scaffold(body: SizedBox.shrink());
        }
        return _HomeContent(user: user);
      },
    );
  }
}

class _HomeContent extends ConsumerWidget {
  final AppUser user;
  const _HomeContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicinesProvider(user.uid));
    final mealsAsync = ref.watch(todayMealsProvider(user.uid));
    final activityAsync = ref.watch(activityLogsProvider(user.uid));
    final notifsAsync = ref.watch(notificationsProvider(user.uid));
    final unreadCount = notifsAsync.asData?.value.where((n) => !n.isRead).length ?? 0;

    final greeting = _greeting();
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(medicinesProvider(user.uid)),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                            const SizedBox(height: 2),
                            Text(user.name.isNotEmpty ? user.name : 'Patient', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.foreground)),
                            const SizedBox(height: 2),
                            Text(today, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_outlined, color: AppColors.foreground, size: 22),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: 0, right: 0,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                      unreadCount > 9 ? '9+' : '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Quick Actions
                    Row(children: [
                      _QuickAction(icon: Icons.medication_rounded, label: 'Medicines', color: AppColors.primary, onTap: () => context.go('/care')),
                      const SizedBox(width: 12),
                      _QuickAction(icon: Icons.restaurant_rounded, label: 'Log Meal', color: AppColors.success, onTap: () => context.go('/care')),
                      const SizedBox(width: 12),
                      _QuickAction(icon: Icons.directions_walk_rounded, label: 'Activity', color: AppColors.warning, onTap: () => context.go('/activity')),
                      const SizedBox(width: 12),
                      _QuickAction(icon: Icons.calendar_month_rounded, label: 'Appoints', color: AppColors.doctorPrimary, onTap: () => context.push('/appointments')),
                    ]),
                    const SizedBox(height: 28),

                    // Health Stats
                    const SectionHeader(title: 'Today\'s Overview'),
                    const SizedBox(height: 12),
                    medsAsync.when(
                      data: (meds) {
                        final taken = meds.where((m) => m.takenToday).length;
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            StatCard(label: 'Medicines', value: '$taken/${meds.length}', unit: 'taken', icon: Icons.medication_rounded, color: AppColors.primary, onTap: () => context.go('/care')),
                            mealsAsync.when(
                              data: (meals) {
                                final cal = meals.fold(0, (sum, m) => sum + (m.calories ?? 0));
                                return StatCard(label: 'Calories', value: '$cal', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: AppColors.warning, onTap: () => context.go('/care'));
                              },
                              loading: () => const StatCard(label: 'Calories', value: '--', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: AppColors.warning),
                              error: (_, __) => const StatCard(label: 'Calories', value: '--', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: AppColors.warning),
                            ),
                            activityAsync.when(
                              data: (logs) {
                                final todayLogs = logs.where((l) {
                                  final now = DateTime.now();
                                  return l.loggedAt.day == now.day && l.loggedAt.month == now.month;
                                }).toList();
                                final steps = todayLogs.fold(0, (s, l) => s + (l.steps ?? 0));
                                return StatCard(label: 'Steps', value: '$steps', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success, onTap: () => context.go('/activity'));
                              },
                              loading: () => const StatCard(label: 'Steps', value: '--', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success),
                              error: (_, __) => const StatCard(label: 'Steps', value: '--', unit: 'today', icon: Icons.directions_walk_rounded, color: AppColors.success),
                            ),
                            StatCard(label: 'Appointments', value: '0', unit: 'pending', icon: Icons.calendar_today_rounded, color: AppColors.doctorPrimary, onTap: () => context.push('/appointments')),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 28),

                    // Upcoming medicines
                    SectionHeader(title: 'Upcoming Medicines', action: 'See all', onAction: () => context.go('/care')),
                    const SizedBox(height: 12),
                    medsAsync.when(
                      data: (meds) {
                        if (meds.isEmpty) {
                          return const EmptyState(icon: Icons.medication_outlined, title: 'No Medicines', subtitle: 'Add your first medicine in the Care tab');
                        }
                        return Column(
                          children: meds.take(3).map((med) => _MedReminder(medicine: med, uid: user.uid)).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 20),

                    // My doctors shortcut
                    GestureDetector(
                      onTap: () => context.push('/my-doctors'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.doctorPrimary, Color(0xFF9F67EA)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.people_rounded, color: Colors.white, size: 28),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('My Doctors', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                  Text('View prescriptions & book appointments', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter'), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _MedReminder extends ConsumerWidget {
  final dynamic medicine;
  final String uid;
  const _MedReminder({required this.medicine, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taken = medicine.takenToday;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: taken ? AppColors.successLight : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (taken ? AppColors.success : AppColors.primary).withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.medication_rounded, color: taken ? AppColors.success : AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                Text('${medicine.dosage} - ${medicine.frequency}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter')),
              ],
            ),
          ),
          if (!taken)
            GestureDetector(
              onTap: () => ref.read(medicineNotifierProvider.notifier).logDose(uid, medicine.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                child: const Text('Take', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
            )
          else
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
        ],
      ),
    );
  }
}
