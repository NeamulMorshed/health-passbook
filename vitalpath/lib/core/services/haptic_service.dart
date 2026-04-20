import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'haptic_service.g.dart';

/// VitalPath Haptic Feedback Service.
///
/// Implements the SRS §7 haptic design spec:
/// - Medicine logged: Short, sharp (light impact)
/// - Step goal reached: Long, celebratory (heavy + medium)
/// - Warning/overdose: Warning pattern (error)
/// - Log action: Light confirmation
///
/// "In an Antigravity app, the user should feel the success of their action
/// before the UI even finishes the animation." — Technology Blueprint §3
class HapticService {
  /// Medicine "taken" confirmation — Short, sharp (SRS §7)
  Future<void> medicineImpact() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Generic "Log" action confirmation — Single light impact
  Future<void> logAction() => HapticFeedback.lightImpact();

  /// Step goal reached — Long, celebratory (SRS §7)
  Future<void> stepGoalImpact() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  /// Per-km haptic during GPS walk (SRS §4.3)
  Future<void> kilometerReached() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  /// Warning — overdose alert, destructive action
  Future<void> warningImpact() async {
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.vibrate();
  }

  /// Success — gentle confirmation
  Future<void> success() => HapticFeedback.mediumImpact();

  /// Error — invalid input
  Future<void> error() => HapticFeedback.vibrate();

  /// Selection change — light tap
  Future<void> selection() => HapticFeedback.selectionClick();

  /// Button press — bare minimum feedback
  Future<void> tap() => HapticFeedback.lightImpact();
}

@riverpod
HapticService hapticService(Ref ref) => HapticService();
