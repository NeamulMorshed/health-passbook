import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// VitalPath's Material 3 theme configuration.
/// "Antigravity" design principles: 60fps transitions, zero visual friction.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _lightColorScheme,
        textTheme: _textTheme,
        appBarTheme: _appBarTheme,
        cardTheme: _cardTheme,
        elevatedButtonTheme: _elevatedButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme,
        textButtonTheme: _textButtonTheme,
        inputDecorationTheme: _inputDecorationTheme,
        bottomNavigationBarTheme: _bottomNavTheme,
        floatingActionButtonTheme: _fabTheme,
        chipTheme: _chipTheme,
        dialogTheme: _dialogTheme,
        snackBarTheme: _snackBarTheme,
        pageTransitionsTheme: _pageTransitionsTheme,
        scaffoldBackgroundColor: AppColors.surface,
        dividerColor: AppColors.divider,
        splashFactory: InkRipple.splashFactory,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkColorScheme,
        textTheme: _textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.surfaceDark,
      );

  // ── Color Scheme ─────────────────────────────────────────────
  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    secondary: AppColors.accentOrange,
    surface: AppColors.surface,
    error: AppColors.error,
    onPrimary: AppColors.white,
    onSecondary: AppColors.black,
    onSurface: AppColors.textPrimary,
    onError: AppColors.white,
  );

  static final ColorScheme _darkColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  );

  // ── Typography — Plus Jakarta Sans ──────────────────────────
  static final TextTheme _textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
    // Display
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 57, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 45, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    ),
    // Headlines
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    ),
    headlineSmall: GoogleFonts.plusJakartaSans(
      fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
    ),
    // Title
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
    ),
    titleSmall: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
    ),
    // Body
    bodyLarge: GoogleFonts.plusJakartaSans(
      fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
      height: 1.6,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary,
      height: 1.4,
    ),
    // Label
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.plusJakartaSans(
      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
    ),
    labelSmall: GoogleFonts.plusJakartaSans(
      fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary,
      letterSpacing: 0.5,
    ),
  );

  // ── AppBar ───────────────────────────────────────────────────
  static final AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    centerTitle: false,
    titleTextStyle: GoogleFonts.plusJakartaSans(
      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    ),
    systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
    ),
  );

  // ── Card ─────────────────────────────────────────────────────
  static final CardThemeData _cardTheme = CardThemeData(
    color: AppColors.cardBackground,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  );

  // ── Elevated Button ───────────────────────────────────────────
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: const Size(double.infinity, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── Outlined Button ───────────────────────────────────────────
  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      minimumSize: const Size(double.infinity, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── Text Button ───────────────────────────────────────────────
  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── Input Decoration ─────────────────────────────────────────
  static final InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textTertiary,
    ),
    labelStyle: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
    ),
  );

  // ── Bottom Navigation ─────────────────────────────────────────
  static final BottomNavigationBarThemeData _bottomNavTheme =
      BottomNavigationBarThemeData(
    type: BottomNavigationBarType.fixed,
    backgroundColor: AppColors.white,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textTertiary,
    elevation: 0,
    selectedLabelStyle: GoogleFonts.plusJakartaSans(
      fontSize: 11, fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: GoogleFonts.plusJakartaSans(
      fontSize: 11, fontWeight: FontWeight.w400,
    ),
  );

  // ── FAB ───────────────────────────────────────────────────────
  static const FloatingActionButtonThemeData _fabTheme =
      FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    elevation: 4,
    shape: CircleBorder(),
  );

  // ── Chip ──────────────────────────────────────────────────────
  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: AppColors.surfaceAlt,
    selectedColor: AppColors.primary.withOpacity(0.15),
    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
    side: BorderSide.none,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  );

  // ── Dialog ───────────────────────────────────────────────────
  static final DialogThemeData _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  );

  // ── SnackBar ─────────────────────────────────────────────────
  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.textPrimary,
    contentTextStyle: GoogleFonts.plusJakartaSans(
      color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  // ── Page Transitions — Antigravity ────────────────────────────
  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
