import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GamificationProfile {
  final int hp;
  final int medStreak;
  final int mealStreak;
  final int activityStreak;
  final DateTime? lastMedDate;
  final DateTime? lastMealDate;
  final DateTime? lastActivityDate;
  final List<String> badgeIds;
  final int weeklyMedDays;
  final int weeklyMealDays;
  final int weeklyActivityDays;
  final DateTime? weekStartDate;
  final int dailyMedDoses;

  const GamificationProfile({
    this.hp = 0,
    this.medStreak = 0,
    this.mealStreak = 0,
    this.activityStreak = 0,
    this.lastMedDate,
    this.lastMealDate,
    this.lastActivityDate,
    this.badgeIds = const [],
    this.weeklyMedDays = 0,
    this.weeklyMealDays = 0,
    this.weeklyActivityDays = 0,
    this.weekStartDate,
    this.dailyMedDoses = 0,
  });

  static const int hpPerLevel = 500;

  int get level => 1 + (hp ~/ hpPerLevel);
  double get levelProgress => (hp % hpPerLevel) / hpPerLevel.toDouble();
  int get hpToNextLevel => hpPerLevel - (hp % hpPerLevel);

  String get levelTitle {
    if (level >= 10) return 'Health Legend';
    if (level >= 7) return 'Elite Achiever';
    if (level >= 5) return 'Health Champion';
    if (level >= 3) return 'Wellness Seeker';
    return 'Health Starter';
  }

  GamificationProfile copyWith({
    int? hp,
    int? medStreak,
    int? mealStreak,
    int? activityStreak,
    DateTime? lastMedDate,
    DateTime? lastMealDate,
    DateTime? lastActivityDate,
    List<String>? badgeIds,
    int? weeklyMedDays,
    int? weeklyMealDays,
    int? weeklyActivityDays,
    DateTime? weekStartDate,
    int? dailyMedDoses,
  }) {
    return GamificationProfile(
      hp: hp ?? this.hp,
      medStreak: medStreak ?? this.medStreak,
      mealStreak: mealStreak ?? this.mealStreak,
      activityStreak: activityStreak ?? this.activityStreak,
      lastMedDate: lastMedDate ?? this.lastMedDate,
      lastMealDate: lastMealDate ?? this.lastMealDate,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      badgeIds: badgeIds ?? this.badgeIds,
      weeklyMedDays: weeklyMedDays ?? this.weeklyMedDays,
      weeklyMealDays: weeklyMealDays ?? this.weeklyMealDays,
      weeklyActivityDays: weeklyActivityDays ?? this.weeklyActivityDays,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      dailyMedDoses: dailyMedDoses ?? this.dailyMedDoses,
    );
  }

  factory GamificationProfile.fromMap(Map<String, dynamic> map) {
    return GamificationProfile(
      hp: (map['hp'] as num?)?.toInt() ?? 0,
      medStreak: (map['medStreak'] as num?)?.toInt() ?? 0,
      mealStreak: (map['mealStreak'] as num?)?.toInt() ?? 0,
      activityStreak: (map['activityStreak'] as num?)?.toInt() ?? 0,
      lastMedDate: (map['lastMedDate'] as Timestamp?)?.toDate(),
      lastMealDate: (map['lastMealDate'] as Timestamp?)?.toDate(),
      lastActivityDate: (map['lastActivityDate'] as Timestamp?)?.toDate(),
      badgeIds: (map['badgeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      weeklyMedDays: (map['weeklyMedDays'] as num?)?.toInt() ?? 0,
      weeklyMealDays: (map['weeklyMealDays'] as num?)?.toInt() ?? 0,
      weeklyActivityDays: (map['weeklyActivityDays'] as num?)?.toInt() ?? 0,
      weekStartDate: (map['weekStartDate'] as Timestamp?)?.toDate(),
      dailyMedDoses: (map['dailyMedDoses'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'hp': hp,
    'medStreak': medStreak,
    'mealStreak': mealStreak,
    'activityStreak': activityStreak,
    'lastMedDate': lastMedDate != null ? Timestamp.fromDate(lastMedDate!) : null,
    'lastMealDate': lastMealDate != null ? Timestamp.fromDate(lastMealDate!) : null,
    'lastActivityDate': lastActivityDate != null ? Timestamp.fromDate(lastActivityDate!) : null,
    'badgeIds': badgeIds,
    'weeklyMedDays': weeklyMedDays,
    'weeklyMealDays': weeklyMealDays,
    'weeklyActivityDays': weeklyActivityDays,
    'weekStartDate': weekStartDate != null ? Timestamp.fromDate(weekStartDate!) : null,
    'dailyMedDoses': dailyMedDoses,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<BadgeDefinition> kAllBadges = [
  BadgeDefinition(id: 'med_first',    name: 'First Dose',      description: 'Logged your first medicine',     icon: Icons.medication_rounded,       color: Color(0xFF6366F1)),
  BadgeDefinition(id: 'meal_first',   name: 'First Meal',      description: 'Logged your first meal',         icon: Icons.restaurant_rounded,       color: Color(0xFF22C55E)),
  BadgeDefinition(id: 'active_first', name: 'First Steps',     description: 'Logged your first activity',     icon: Icons.directions_walk_rounded,  color: Color(0xFFF59E0B)),
  BadgeDefinition(id: 'med_7',        name: 'Dedicated',       description: '7-day medicine streak',          icon: Icons.local_fire_department_rounded, color: Color(0xFF6366F1)),
  BadgeDefinition(id: 'meal_7',       name: 'Healthy Eater',   description: '7-day meal logging streak',      icon: Icons.favorite_rounded,         color: Color(0xFF22C55E)),
  BadgeDefinition(id: 'activity_5',   name: 'Stay Active',     description: '5-day activity streak',          icon: Icons.fitness_center_rounded,   color: Color(0xFFF59E0B)),
  BadgeDefinition(id: 'hp_500',       name: 'Centurion',       description: 'Reached 500 Health Points',      icon: Icons.military_tech_rounded,    color: Color(0xFFF59E0B)),
  BadgeDefinition(id: 'hp_1000',      name: 'Elite',           description: 'Reached 1000 Health Points',     icon: Icons.star_rounded,             color: Color(0xFF8B5CF6)),
  BadgeDefinition(id: 'streak_shield', name: 'Streak Shield', description: 'Maintained a 3-day combined streak', icon: Icons.shield_rounded, color: Color(0xFF0EA5E9)),
];
