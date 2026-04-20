import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  final String id;
  final String patientId;
  final String type; // walk, run, steps
  final int durationSeconds;
  final double? distanceKm;
  final int? steps;
  final int? caloriesBurned;
  final DateTime loggedAt;

  const ActivityLog({
    required this.id,
    required this.patientId,
    required this.type,
    required this.durationSeconds,
    this.distanceKm,
    this.steps,
    this.caloriesBurned,
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
        'loggedAt': Timestamp.fromDate(loggedAt),
      };
}
