/// Application-wide constants for VitalPath.
/// Single source of truth for all magic numbers defined in the SRS.
abstract final class AppConstants {
  // ── App Identity ──────────────────────────────────────────────
  static const String appName = 'VitalPath';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Health, Passbooked.';

  // ── Refill Logic (SRS §4.1) ──────────────────────────────────
  /// Trigger "Refill Reminder" when pills remaining reach this threshold
  static const int refillThreshold = 5;

  // ── Duplicate Log Prevention (SRS §5.2) ──────────────────────
  /// Window (in minutes) within which a second log attempt triggers overdose warning
  static const int duplicateLogWindowMinutes = 15;

  // ── Notification Fatigue Detection (SRS §5.2) ────────────────
  /// After N ignored notifications, suggest alternative reminder style
  static const int notificationFatigueThreshold = 5;

  // ── Activity (SRS §4.3) ───────────────────────────────────────
  static const int defaultStepGoal = 10000;
  /// Background step sync interval in minutes
  static const int stepSyncIntervalMinutes = 15;
  /// Haptic every N kilometers during GPS walk
  static const double gpsHapticKmInterval = 1.0;

  // ── Nutrition (SRS §4.2) ─────────────────────────────────────
  /// Pre-meal reminder: N minutes before scheduled meal time
  static const int preMealReminderMinutes = 15;

  // ── Performance (SRS §6.1 — Antigravity) ─────────────────────
  /// Maximum acceptable UI response latency
  static const int maxUiLatencyMs = 100;

  // ── Sync Engine (SRS §5.1) ────────────────────────────────────
  static const int syncRetryMaxAttempts = 3;
  static const int syncRetryDelaySeconds = 30;

  // ── Doctor Sync (SRS §4.4) ────────────────────────────────────
  static const int syncCodeLength = 6;
  static const int syncCodeExpiryMinutes = 15;

  // ── Validation Thresholds (SRS §5.1) ─────────────────────────
  static const double maxReasonableWeightKg = 400.0;
  static const double minReasonableWeightKg = 1.0;
  static const double maxReasonableHeightCm = 300.0;
  static const double minReasonableHeightCm = 30.0;

  // ── Storage Keys ─────────────────────────────────────────────
  static const String kUserProfileKey = 'user_profile';
  static const String kOnboardingComplete = 'onboarding_complete';
  static const String kThemeMode = 'theme_mode';
  static const String kUnitPreference = 'unit_preference'; // 'km' | 'miles'
  static const String kTimezoneKey = 'home_timezone';
  static const String kNotificationFatigueCount = 'notification_fatigue_count';
  static const String kBiometricEnabled = 'biometric_enabled';

  // ── Supabase Table Names ──────────────────────────────────────
  static const String tableUsers = 'users';
  static const String tableMedicines = 'medicines';
  static const String tableMedicineLogs = 'medicine_logs';
  static const String tableMealRoutines = 'meal_routines';
  static const String tableMealLogs = 'meal_logs';
  static const String tableActivityLogs = 'activity_logs';
  static const String tableWalkSessions = 'walk_sessions';
  static const String tableDoctorConnections = 'doctor_connections';
  static const String tablePrescriptions = 'prescriptions';
  static const String tableAdherenceReports = 'adherence_reports';

  // ── Route Names ───────────────────────────────────────────────
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routePhoneAuth = '/auth/phone';
  static const String routeOtpVerify = '/auth/otp';
  static const String routeHealthProfile = '/auth/health-profile';
  static const String routeDashboard = '/dashboard';
  static const String routeMedicineList = '/medicine';
  static const String routeMedicineAdd = '/medicine/add';
  static const String routeMedicineEdit = '/medicine/edit';
  static const String routeMedicineDetail = '/medicine/detail';
  static const String routeNutrition = '/nutrition';
  static const String routeNutritionAdd = '/nutrition/add';
  static const String routeActivity = '/activity';
  static const String routeGpsWalk = '/activity/walk';
  static const String routeDoctorSync = '/doctor';
  static const String routeQrScanner = '/doctor/scan';
  static const String routeAdherenceReport = '/doctor/report';
  static const String routeProfile = '/profile';
  static const String routeSettings = '/settings';
}
