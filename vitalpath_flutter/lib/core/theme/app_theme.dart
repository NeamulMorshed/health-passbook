import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary green brand — #0F9D77
  static const primary         = Color(0xFF0F9D77);
  static const primaryLight    = Color(0xFF3DB896);
  static const primaryDark     = Color(0xFF0B7A5E);
  static const primaryTint     = Color(0xFFE8F5F1);
  static const primaryXLight   = Color(0xFFF2FAF7);

  // Page and surface
  static const pageBackground  = Color(0xFFF2F2F0);
  static const surface         = Color(0xFFFFFFFF);
  static const surfaceSubtle   = Color(0xFFF7F7F5);

  // Text
  static const textPrimary     = Color(0xFF111827);
  static const textSecondary   = Color(0xFF6B7280);
  static const textTertiary    = Color(0xFF9CA3AF);
  static const textOnPrimary   = Color(0xFFFFFFFF);

  // Borders
  static const border          = Color(0xFFE5E5E3);
  static const borderStrong    = Color(0xFFD1D5DB);

  // Semantic
  static const success         = Color(0xFF16A34A);
  static const successLight    = Color(0xFFDCFCE7);
  static const warning         = Color(0xFFD97706);
  static const warningLight    = Color(0xFFFEF3C7);
  static const destructive     = Color(0xFFDC2626);
  static const destructiveLight = Color(0xFFFEE2E2);
  static const info            = Color(0xFF3B82F6);
  static const infoLight       = Color(0xFFEFF6FF);

  // Legacy aliases — keeps existing screens compiling without any changes
  static const background      = pageBackground;
  static const muted           = surfaceSubtle;
  static const mutedForeground = textSecondary;
  static const foreground      = textPrimary;
  static const cardForeground  = textPrimary;
  static const doctorPrimary   = primary;
  static const doctorLight     = primaryTint;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pageBackground,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.destructive,
      ),

      textTheme: GoogleFonts.openSansTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        displayLarge:   GoogleFonts.openSans(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        displayMedium:  GoogleFonts.openSans(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        displaySmall:   GoogleFonts.openSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium: GoogleFonts.openSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineSmall:  GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge:     GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium:    GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge:      GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium:     GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodySmall:      GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        labelLarge:     GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelSmall:     GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.openSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.openSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.openSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.openSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.destructive, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.openSans(fontSize: 14, color: AppColors.textTertiary),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 68,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.textTertiary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.openSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w400),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSubtle,
        selectedColor: AppColors.primaryXLight,
        side: const BorderSide(color: AppColors.border, width: 0.5),
        labelStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
