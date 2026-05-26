import 'package:cloud_firestore/cloud_firestore.dart';

class VitalReading {
  final String id;
  final String patientId;
  final String
      type; // 'bp_systolic' | 'bp_diastolic' | 'glucose' | 'temp' | 'spo2' | 'pulse'
  final double value;
  final String unit;
  final DateTime recordedAt;
  final String? note;

  const VitalReading({
    required this.id,
    required this.patientId,
    required this.type,
    required this.value,
    required this.unit,
    required this.recordedAt,
    this.note,
  });

  factory VitalReading.fromMap(Map<String, dynamic> map, String id) {
    return VitalReading(
      id: id,
      patientId: map['patientId'] ?? '',
      type: map['type'] ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      recordedAt: (map['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'type': type,
        'value': value,
        'unit': unit,
        'recordedAt': Timestamp.fromDate(recordedAt),
        'note': note,
      };
}

class VitalType {
  static const bpSystolic = 'bp_systolic';
  static const bpDiastolic = 'bp_diastolic';
  static const glucose = 'glucose';
  static const temp = 'temp';
  static const spo2 = 'spo2';
  static const pulse = 'pulse';

  static const allTypes = [bpSystolic, bpDiastolic, glucose, temp, spo2, pulse];

  static String labelFor(String type) => switch (type) {
        bpSystolic => 'BP Systolic',
        bpDiastolic => 'BP Diastolic',
        glucose => 'Blood Glucose',
        temp => 'Temperature',
        spo2 => 'SpO₂',
        pulse => 'Pulse',
        _ => type,
      };

  static String unitFor(String type) => switch (type) {
        bpSystolic || bpDiastolic => 'mmHg',
        glucose => 'mg/dL',
        temp => '°C',
        spo2 => '%',
        pulse => 'bpm',
        _ => '',
      };

  // Normal ranges — returns (min, max)
  static (double, double) normalRange(String type) => switch (type) {
        bpSystolic => (90, 120),
        bpDiastolic => (60, 80),
        glucose => (70, 140),
        temp => (36.1, 37.2),
        spo2 => (95, 100),
        pulse => (60, 100),
        _ => (0, double.infinity),
      };

  static bool isNormal(String type, double value) {
    final (min, max) = normalRange(type);
    return value >= min && value <= max;
  }
}
