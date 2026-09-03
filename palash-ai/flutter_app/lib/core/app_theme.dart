import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  EduVaani — Design System
//  Rich indigo × teal palette, Material 3
// ─────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1E293B); // Deep Indigo
  static const Color primaryLight = Color(0xFF475569); // Slate-600
  static const Color primaryDark = Color(0xFF0F172A); // Slate-950
  static const Color secondary = Color(0xFF64748B); // Slate-500
  static const Color accent = Color(0xFFCBD5E1); // Slate-300
  static const Color teal = Color(0xFF0F766E); // Teal-700

  // Semantics
  static const Color success = Color(0xFF166534); // Dark green
  static const Color warning = Color(0xFFB45309); // Amber-700
  static const Color error = Color(0xFFB91C1C);
  static const Color info = Color(0xFF1D4ED8);

  // Neutrals (light)
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textHint = Color(0xFF64748B);

  // Gradient stops
  static const Color gradStart = Color(0xFF1E293B);
  static const Color gradMid = Color(0xFF334155);
  static const Color gradEnd = Color(0xFF475569);

  // Card accent colours (one per feature)
  static const Color cardLessons = Color(0xFF7C3AED);
  static const Color cardVoice = Color(0xFF0EA5E9);
  static const Color cardText = Color(0xFF2563EB);
  static const Color cardWorksheet = Color(0xFF0F766E);
  static const Color cardFlashcard = Color(0xFFEAB308);
  static const Color cardAssessment = Color(0xFFDC2626);
  static const Color cardProgress = Color(0xFF16A34A);
  static const Color cardSync = Color(0xFF64748B);
  static const Color cardScanner = Color(0xFF1E293B);
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
    colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient card(Color base) => LinearGradient(
    colors: [base.withValues(alpha: 0.12), Colors.white],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Shadow helpers ────────────────────────────

class AppShadows {
  AppShadows._();

  static List<BoxShadow> sm = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> md = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> colored(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.18),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

// ── Radius tokens ─────────────────────────────

class AppRadius {
  AppRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
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

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: 'Roboto',

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textHint),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),

      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamily: 'Roboto',
      ),
    );
  }

  static ThemeData get dark {
    const seed = AppColors.primary;

    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.teal,
      surface: const Color(0xFF0F172A),
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111827),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
        labelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primaryLight,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
        fontFamily: 'Roboto',
      ),
    );
  }
}
