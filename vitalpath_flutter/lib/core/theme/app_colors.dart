import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VitalPath Design Token System — mirrors CSS custom properties in HTML proto
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Primary (Indigo Blue) ─────────────────────────────────
  static const primary       = Color(0xFF5C6FFF);
  static const primaryDark   = Color(0xFF4A5CE0);
  static const primaryMid    = Color(0xFF8A97FF);
  static const primaryLight  = Color(0xFFEEF0FF);

  // ── Secondary (Mint Green) ────────────────────────────────
  static const secondary     = Color(0xFF3DBE7A);
  static const secondaryDark = Color(0xFF35A868);
  static const secondaryLight= Color(0xFFE8F8F0);

  // ── Error (Coral Red) ─────────────────────────────────────
  static const error         = Color(0xFFF03E3E);
  static const errorLight    = Color(0xFFFFEEEE);

  // ── Warning (Amber) ───────────────────────────────────────
  static const warning       = Color(0xFFFFB020);
  static const warningLight  = Color(0xFFFFF4E0);

  // ── Info (Sky Blue) ───────────────────────────────────────
  static const info          = Color(0xFF2B91FF);
  static const infoLight     = Color(0xFFE3F0FF);

  // ── Neutral Surface ───────────────────────────────────────
  static const background    = Color(0xFFF0F2F8);
  static const surface       = Color(0xFFFFFFFF);
  static const border        = Color(0xFFE8EAEF);
  static const divider       = Color(0xFFF0F2F8);

  // ── Text ──────────────────────────────────────────────────
  static const text1         = Color(0xFF1A1D2E);    // headlines
  static const text2         = Color(0xFF4A4E6B);    // body
  static const text3         = Color(0xFF8A8FA8);    // captions / hints
  static const textOnPrimary = Color(0xFFFFFFFF);

  // ── Special ───────────────────────────────────────────────
  static const shellBackground = Color(0xFF111318); // outer phone shell
  static const cardShadow      = Color(0x0F1A1D2E);
  static const elevatedShadow  = Color(0x265C6FFF);

  // ── Gradient ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5C6FFF), Color(0xFF3DBE7A)],
  );
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment(0, -1),
    end: Alignment(0.4, 1),
    colors: [Color(0xFF1A1D2E), Color(0xFF232645)],
  );

  // ── Shadow presets ────────────────────────────────────────
  static List<BoxShadow> get cardShadows => [
    BoxShadow(color: cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
    BoxShadow(color: const Color(0x141A1D2E), blurRadius: 1),
  ];
  static List<BoxShadow> get elevatedShadows => [
    BoxShadow(color: elevatedShadow, blurRadius: 20, offset: const Offset(0, 4)),
    BoxShadow(color: cardShadow, blurRadius: 4, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> get primaryButtonShadow => [
    BoxShadow(color: primary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
  ];
}
