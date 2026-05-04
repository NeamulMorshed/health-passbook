import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/gamification_provider.dart';
import '../../../models/gamification.dart';

void _showHowToEarn(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HowToEarnSheet(),
  );
}

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Health Rewards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'How to earn HP',
            onPressed: () => _showHowToEarn(context),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: 'Pull to refresh or try again.'),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          final gamAsync = ref.watch(gamificationProvider(user.uid));
          return gamAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: CircularProgressIndicator()),
            data: (profile) => _GamificationContent(profile: profile),
          );
        },
      ),
    );
  }
}

class _GamificationContent extends StatelessWidget {
  final GamificationProfile profile;
  const _GamificationContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _LevelCard(profile: profile),
        const SizedBox(height: 20),
        _StreakSection(profile: profile),
        const SizedBox(height: 20),
        _WeeklyChallenge(profile: profile),
        const SizedBox(height: 20),
        _BadgesSection(profile: profile),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final GamificationProfile profile;
  const _LevelCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 52,
            lineWidth: 8,
            percent: profile.levelProgress,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            progressColor: Colors.white,
            circularStrokeCap: CircularStrokeCap.round,
            center: Text(
              'Lv\n${profile.level}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Inter'),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.levelTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.hp} HP total',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter'),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: profile.levelProgress,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${profile.hpToNextLevel} HP to next level',
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Inter'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakSection extends StatelessWidget {
  final GamificationProfile profile;
  const _StreakSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Active Streaks'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StreakTile(label: 'Medicine', streak: profile.medStreak, color: AppColors.primary, icon: Icons.medication_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StreakTile(label: 'Meals', streak: profile.mealStreak, color: AppColors.success, icon: Icons.restaurant_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StreakTile(label: 'Activity', streak: profile.activityStreak, color: AppColors.warning, icon: Icons.directions_walk_rounded)),
        ]),
      ],
    );
  }
}

class _StreakTile extends StatelessWidget {
  final String label;
  final int streak;
  final Color color;
  final IconData icon;
  const _StreakTile({required this.label, required this.streak, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isActive = streak > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? color.withValues(alpha: 0.25) : AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, color: isActive ? color : AppColors.mutedForeground, size: 22),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (isActive) const Text('🔥', style: TextStyle(fontSize: 12)),
          Text(
            '$streak',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isActive ? color : AppColors.mutedForeground, fontFamily: 'Inter'),
          ),
        ]),
        Text('days', style: TextStyle(fontSize: 10, color: isActive ? color : AppColors.mutedForeground, fontFamily: 'Inter')),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontFamily: 'Inter'), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _WeeklyChallenge extends StatelessWidget {
  final GamificationProfile profile;
  const _WeeklyChallenge({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Weekly Challenges'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            _ChallengeRow(label: 'Take medicine 5 days', current: profile.weeklyMedDays, target: 5, color: AppColors.primary),
            const SizedBox(height: 14),
            _ChallengeRow(label: 'Log meals 5 days', current: profile.weeklyMealDays, target: 5, color: AppColors.success),
            const SizedBox(height: 14),
            _ChallengeRow(label: 'Stay active 3 days', current: profile.weeklyActivityDays, target: 3, color: AppColors.warning),
          ]),
        ),
      ],
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final Color color;
  const _ChallengeRow({required this.label, required this.current, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = (current / target).clamp(0.0, 1.0);
    final done = current >= target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (done) const Text('✅ ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: done ? AppColors.success : AppColors.foreground, fontFamily: 'Inter'))),
          Text('$current/$target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(done ? AppColors.success : color),
          ),
        ),
      ],
    );
  }
}

class _BadgesSection extends StatelessWidget {
  final GamificationProfile profile;
  const _BadgesSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Badges (${profile.badgeIds.length}/${kAllBadges.length})'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: kAllBadges.length,
          itemBuilder: (_, i) {
            final badge = kAllBadges[i];
            final earned = profile.badgeIds.contains(badge.id);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: earned ? badge.color.withValues(alpha: 0.08) : AppColors.muted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: earned ? badge.color.withValues(alpha: 0.3) : AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    badge.icon,
                    color: earned ? badge.color : AppColors.mutedForeground.withValues(alpha: 0.4),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: earned ? AppColors.foreground : AppColors.mutedForeground,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: earned ? AppColors.mutedForeground : AppColors.mutedForeground.withValues(alpha: 0.5),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── How to Earn HP Sheet ──────────────────────────────────────────────────────

class _HowToEarnSheet extends StatelessWidget {
  const _HowToEarnSheet();

  static const _items = [
    (icon: Icons.medication_rounded,            color: Color(0xFF6366F1), action: 'Log medicine on time',      hp: '+10 HP'),
    (icon: Icons.restaurant_rounded,            color: Color(0xFF22C55E), action: 'Log a meal',                hp: '+5 HP'),
    (icon: Icons.directions_walk_rounded,       color: Color(0xFFF59E0B), action: 'Log an activity session',   hp: '+10 HP'),
    (icon: Icons.local_fire_department_rounded, color: Color(0xFFEF4444), action: '7-day medicine streak',     hp: '+50 HP'),
    (icon: Icons.favorite_rounded,              color: Color(0xFF22C55E), action: '7-day meal streak',         hp: '+50 HP'),
    (icon: Icons.fitness_center_rounded,        color: Color(0xFFF59E0B), action: '5-day activity streak',     hp: '+30 HP'),
    (icon: Icons.emoji_events_rounded,          color: Color(0xFF8B5CF6), action: 'Complete weekly challenge', hp: '+100 HP'),
    (icon: Icons.military_tech_rounded,         color: Color(0xFFF59E0B), action: 'Unlock a badge',            hp: '+50 HP'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'How to Earn HP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Health Points (HP) level you up and unlock badges.',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 20),
          ..._items.map((item) => _EarnRow(item: item)),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(fontFamily: 'Inter')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final ({IconData icon, Color color, String action, String hp}) item;
  const _EarnRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: item.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(item.action,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(item.hp,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Inter')),
        ),
      ]),
    );
  }
}
