import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/app_constants.dart';

part 'health_connector_service.g.dart';

/// VitalPath Health Connector Service.
///
/// Unified bridge to Android Health Connect (SRS §2.1, Tech Blueprint §1.1).
/// Pulls steps, distance, and calories in the background every 15 minutes (SRS §4.3).
/// Uses Flutter Isolates for heavy data parsing to maintain 60fps (Tech Blueprint §3).
class HealthConnectorService {
  final Health _health = Health();

  static const List<HealthDataType> _requestedTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool _isAuthorized = false;

  /// Request Health Connect permissions from the user.
  Future<bool> requestPermissions() async {
    try {
      _health.configure(useHealthConnectIfAvailable: true);

      final hasPermissions =
          await _health.hasPermissions(_requestedTypes, permissions: _permissions);

      if (hasPermissions ?? false) {
        _isAuthorized = true;
        return true;
      }

      _isAuthorized = await _health.requestAuthorization(
        _requestedTypes,
        permissions: _permissions,
      );
      return _isAuthorized;
    } catch (e) {
      debugPrint('[HealthConnector] Permission error: $e');
      return false;
    }
  }

  /// Check if Health Connect is available on this device.
  Future<bool> isAvailable() async {
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      return false;
    }
  }

  /// Fetch step count for today.
  /// Called by background sync every 15 minutes (SRS §4.3).
  Future<StepData> fetchTodaySteps() async {
    if (!_isAuthorized) {
      final granted = await requestPermissions();
      if (!granted) return StepData.empty();
    }

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final steps = await _health.getTotalStepsInInterval(midnight, now);
      final distance = await _fetchTodayDistance(midnight, now);
      final calories = await _fetchTodayCalories(midnight, now);

      return StepData(
        stepCount: steps ?? 0,
        distanceMeters: distance,
        caloriesBurned: calories,
        fetchedAt: now,
      );
    } catch (e) {
      debugPrint('[HealthConnector] Step fetch error: $e');
      return StepData.empty();
    }
  }

  /// Fetch step history for chart (uses Isolate to avoid jank — Tech Blueprint §3).
  Future<List<DailyStepData>> fetchStepHistory({int days = 30}) async {
    if (!_isAuthorized) return [];

    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));

      // Heavy computation moved to isolate to protect UI thread (Tech Blueprint §3)
      final rawData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.STEPS],
      );

      // Process in isolate
      return await compute(_processStepHistory, rawData);
    } catch (e) {
      debugPrint('[HealthConnector] History fetch error: $e');
      return [];
    }
  }

  Future<double> _fetchTodayDistance(DateTime start, DateTime end) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
      );
      return data.fold<double>(
        0.0,
        (sum, point) => sum + (point.value as NumericHealthValue).numericValue.toDouble(),
      );
    } catch (_) {
      return 0.0;
    }
  }

  Future<double?> _fetchTodayCalories(DateTime start, DateTime end) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      return data.fold<double>(
        0.0,
        (sum, point) => sum + (point.value as NumericHealthValue).numericValue.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Runs in isolate — zero impact on UI thread (Tech Blueprint §3)
List<DailyStepData> _processStepHistory(List<HealthDataPoint> rawData) {
  final Map<String, int> dayMap = {};

  for (final point in rawData) {
    final dateKey =
        '${point.dateFrom.year}-${point.dateFrom.month.toString().padLeft(2, '0')}-${point.dateFrom.day.toString().padLeft(2, '0')}';
    final steps = (point.value as NumericHealthValue).numericValue.toInt();
    dayMap[dateKey] = (dayMap[dateKey] ?? 0) + steps;
  }

  return dayMap.entries
      .map((e) => DailyStepData(date: e.key, steps: e.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

// ── Data Models ───────────────────────────────────────────────

class StepData {
  final int stepCount;
  final double distanceMeters;
  final double? caloriesBurned;
  final DateTime fetchedAt;

  const StepData({
    required this.stepCount,
    required this.distanceMeters,
    this.caloriesBurned,
    required this.fetchedAt,
  });

  factory StepData.empty() => StepData(
        stepCount: 0,
        distanceMeters: 0,
        fetchedAt: DateTime.now(),
      );

  double get distanceKm => distanceMeters / 1000;
  double get distanceMiles => distanceMeters / 1609.34;
  double get progressPercent => stepCount / AppConstants.defaultStepGoal;
}

class DailyStepData {
  final String date; // "yyyy-MM-dd"
  final int steps;

  const DailyStepData({required this.date, required this.steps});
}

@riverpod
HealthConnectorService healthConnectorService(Ref ref) {
  return HealthConnectorService();
}
