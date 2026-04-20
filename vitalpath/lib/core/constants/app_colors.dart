import 'package:flutter/material.dart';

/// VitalPath design system — color tokens.
/// Built on a deep teal/emerald primary with a warm coral accent.
/// Designed for accessibility (WCAG AA compliant contrast ratios).
abstract final class AppColors {
  // ── Primary Palette ────────────────────────────────────────────
  static const Color primary = Color(0xFF0B6E4F);       // Deep Emerald
  static const Color primaryLight = Color(0xFF1A9A70);  // Vibrant Teal
  static const Color primaryDark = Color(0xFF074D37);   // Forest Deep

  // ── Accent / Action ───────────────────────────────────────────
  static const Color accent = Color(0xFFFF6B6B);        // Coral — urgent actions
  static const Color accentOrange = Color(0xFFF7A440);  // Amber — warnings/refills

  // ── Semantic Colours ──────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Neutrals ─────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFFF8FAF9);         // App background
  static const Color surfaceAlt = Color(0xFFEDF3F0);      // Card/section bg
  static const Color surfaceDark = Color(0xFF1C1C1E);     // Dark mode surface

  // ── Text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F1F1A);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  // ── Timeline / Task states ────────────────────────────────────
  /// Completed tasks — faded state (per SRS §7)
  static const Color taskCompleted = Color(0xFFB0C9C0);
  /// Upcoming tasks — elevated/active
  static const Color taskUpcoming = Color(0xFF0B6E4F);
  /// Missed tasks
  static const Color taskMissed = Color(0xFFEF4444);
  /// Verified (doctor-assigned) tasks
  static const Color taskVerified = Color(0xFF3B82F6);

  // ── Card & Divider ────────────────────────────────────────────
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  // ── Medicine Category Colors ──────────────────────────────────
  static const Color medBluePill = Color(0xFF60A5FA);
  static const Color medGreenCapsule = Color(0xFF34D399);
  static const Color medYellowTablet = Color(0xFFFBBF24);
  static const Color medRedLiquid = Color(0xFFF87171);

  // ── Step Progress Gradient ────────────────────────────────────
  static const List<Color> stepGradient = [
    Color(0xFF0B6E4F),
    Color(0xFF34D399),
  ];

  // ── Shadows ───────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0B6E4F).withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
