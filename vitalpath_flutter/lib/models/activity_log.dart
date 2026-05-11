import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityType {
  static const walk = 'walk';
  static const run = 'run';
  static const cycle = 'cycle';
  static const yoga = 'yoga';
  static const swim = 'swim';
  static const gym = 'gym';
  static const other = 'other';

  static const gpsTracked = [walk, run, cycle];
  static const manualLog = [yoga, swim, gym, other];

  static const allTypes = [walk, run, cycle, yoga, swim, gym, other];

  static IconData iconFor(String type) => switch (type) {
    run => Icons.directions_run_rounded,
    cycle => Icons.directions_bike_rounded,
    yoga => Icons.self_improvement_rounded,
    swim => Icons.pool_rounded,
    gym => Icons.fitness_center_rounded,
    other => Icons.sports_rounded,
    _ => Icons.directions_walk_rounded, // walk + fallback
  };

  static String labelFor(String type) => switch (type) {
    run => 'Run',
    cycle => 'Cycle',
    yoga => 'Yoga',
    swim => 'Swim',
    gym => 'Gym',
    other => 'Other',
    _ => 'Walk',
  };
}

class ActivityLog {
  final String id;
  final String patientId;
  final String type; // walk, run, steps
  final int durationSeconds;
  final double? distanceKm;
  final int? steps;
  final int? caloriesBurned;
  final String? notes;
  final DateTime loggedAt;

  const ActivityLog({
    required this.id,
    required this.patientId,
    required this.type,
    required this.durationSeconds,
    this.distanceKm,
    this.steps,
    this.caloriesBurned,
    this.notes,
    required this.loggedAt,
  });

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map, String id) {
    return ActivityLog(
      id: id,
      patientId: map['patientId'] ?? '',
      type: map['type'] ?? 'walk',
      durationSeconds: map['durationSeconds'] ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      steps: map['steps'],
      caloriesBurned: map['caloriesBurned'],
      notes: map['notes'] as String?,
      loggedAt: (map['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'type': type,
        'durationSeconds': durationSeconds,
        'distanceKm': distanceKm,
        'steps': steps,
        'caloriesBurned': caloriesBurned,
        'notes': notes,
        'loggedAt': Timestamp.fromDate(loggedAt),
      };
}
