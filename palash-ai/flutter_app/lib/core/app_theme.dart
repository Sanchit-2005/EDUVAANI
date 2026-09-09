import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
//  EduVaani — Design System
//  Premium Navy × Royal Indigo × Emerald Palette
// ─────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0F172A); // Slate-900 / Deep Navy
  static const Color primaryLight = Color(0xFF334155); // Slate-700
  static const Color primaryDark = Color(0xFF020617); // Slate-950
  static const Color secondary = Color(0xFF475569); // Slate-600
  static const Color accent = Color(0xFF6366F1); // Indigo-500
  static const Color teal = Color(0xFF0D9488); // Teal-600

  // Semantics
  static const Color success = Color(0xFF15803D); // Emerald-700
  static const Color warning = Color(0xFFB45309); // Amber-700
  static const Color error = Color(0xFFB91C1C);
  static const Color info = Color(0xFF1D4ED8);

  // Neutrals (light)
  static const Color surface = Color(0xFFF8FAFC); // Porcelain Slate
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  // AA-safe muted text for visible subtitles on white and off-white surfaces.
  static const Color textHint = Color(0xFF64748B);

  // Gradient stops
  static const Color gradStart = Color(0xFF0F172A);
  static const Color gradMid = Color(0xFF1E293B);
  static const Color gradEnd = Color(0xFF334155);

  // Card accent colours (one per feature)
  static const Color cardLessons = Color(0xFF7C3AED);
  static const Color cardVoice = Color(0xFF0284C7);
  static const Color cardText = Color(0xFF2563EB);
  static const Color cardWorksheet = Color(0xFF0D9488);
  static const Color cardFlashcard = Color(0xD0CA8A04);
  static const Color cardAssessment = Color(0xFFDC2626);
  static const Color cardProgress = Color(0xFF16A34A);
  static const Color cardSync = Color(0xFF64748B);
  static const Color cardScanner = Color(0xFF0F172A);
}

// ── Gradient helpers ──────────────────────────

class AppGradients {
  AppGradients._();

  static const LinearGradient brand = LinearGradient(
    colors: [AppColors.gradStart, AppColors.gradMid, AppColors.gradEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandSubtle = LinearGradient(
    colors: [Color(0xFFF1F5F9), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pageBackground = LinearGradient(
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFF0F4FF),
      Color(0xFFF5F3FF),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient headerBand = LinearGradient(
    colors: [
      Color(0xFFEEF2FF),
      Color(0xFFEDE9FE),
      Color(0xFFF8FAFC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient card(Color base) => LinearGradient(
        colors: [base, Color.lerp(base, AppColors.primaryDark, 0.25)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

// ── Shadow helpers ────────────────────────────

class AppShadows {
  AppShadows._();

  static List<BoxShadow> sm = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> md = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> colored(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

// ── Radius tokens ─────────────────────────────

class AppRadius {
  AppRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double card = 16;
  static const double lg = 18;
  static const double xl = 22;
  static const double full = 999;
}

// ── Spacing tokens ────────────────────────────

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ── Theme builder ─────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const seed = AppColors.primary;

    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.teal,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    final titleTextTheme = GoogleFonts.outfitTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: titleTextTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.primary,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Color(0xFF1E293B),
        ),
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.primary,
        indicatorColor: AppColors.accent.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: Colors.white),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primary,
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.cardText, width: 2),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textHint,
          fontSize: 15,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.cardText,
          fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }

  static ThemeData get dark => light;
}

