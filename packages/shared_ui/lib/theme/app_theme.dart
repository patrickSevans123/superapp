import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Color Palette: Midnight Zinc ────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Backgrounds ─────────────────────────────────────────────────────────
  static const canvas      = Color(0xFF09090B); // zinc-950
  static const surface     = Color(0xFF18181B); // zinc-900
  static const surfaceAlt  = Color(0xFF1F1F23); // between 900-800
  static const elevated    = Color(0xFF27272A); // zinc-800

  // ── Borders ─────────────────────────────────────────────────────────────
  static const border      = Color(0xFF27272A); // zinc-800
  static const borderHover = Color(0xFF3F3F46); // zinc-700

  // ── Accent ──────────────────────────────────────────────────────────────
  static const accent      = Color(0xFF8B5CF6); // violet-500
  static const accentDim   = Color(0xFF7C3AED); // violet-600
  static const accentMuted = Color(0xFF6D28D9); // violet-700

  // ── Text ────────────────────────────────────────────────────────────────
  static const ink         = Color(0xFFFAFAFA); // zinc-50
  static const stone       = Color(0xFFA1A1AA); // zinc-400
  static const hint        = Color(0xFF71717A); // zinc-500
  static const divider     = Color(0xFF27272A); // zinc-800

  // ── Semantic ────────────────────────────────────────────────────────────
  static const error       = Color(0xFFEF4444); // red-500
  static const success     = Color(0xFF34D399); // emerald-400
  static const warning     = Color(0xFFF59E0B); // amber-500

  // ── Orb / decoration ────────────────────────────────────────────────────
  static const orbLight = Color(0x228B5CF6);
  static const orbMid   = Color(0x18EC4899);
}

// ─── Typography ──────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const _base = TextStyle(
    fontFamily: '.SF Pro Display',
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static final display = _base.copyWith(
    fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1,
  );
  static final headline = _base.copyWith(
    fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2,
  );
  static final title = _base.copyWith(
    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3,
  );
  static final body = _base.copyWith(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.55,
  );
  static final caption = _base.copyWith(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.stone, height: 1.4,
  );
  static final label = _base.copyWith(
    fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.8, height: 1.0,
  );
}

// ─── Theme ───────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build();

  static ThemeData _build() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent, secondary: AppColors.accent,
        surface: AppColors.surface, error: AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0, scrolledUnderElevation: 0,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: AppTextStyles.title.copyWith(fontSize: 16),
        iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.stone, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: AppColors.accent.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.ink : AppColors.hint,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accent : AppColors.hint, size: 22,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent, foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: AppTextStyles.label.copyWith(color: Colors.white),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.elevated,
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.stone),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.hint),
        prefixIconColor: AppColors.hint, suffixIconColor: AppColors.hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border, thickness: 1, space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: AppTextStyles.body,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating, elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent.withOpacity(0.20),
        labelStyle: AppTextStyles.caption.copyWith(color: Colors.white),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        headlineMedium: AppTextStyles.headline,
        titleMedium: AppTextStyles.title,
        bodyLarge: AppTextStyles.body.copyWith(fontSize: 15),
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.label,
      ),
    );
  }
}
