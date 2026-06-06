import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Color Palette ───────────────────────────────────────────────────────────

/// Dark-mode palette — "Garuda Dark"
///
/// Named after the national emblem, evoking strength and trust.
/// Dark-first with a single teal-blue accent for brand identity.
class AppColors {
  AppColors._();

  // ── Backgrounds (Garuda Dark) ──────────────────────────────────────────
  static const canvas      = Color(0xFF0F1114); // Surface 0 – page background
  static const surface     = Color(0xFF1A1D23); // Surface 1 – cards
  static const surfaceAlt  = Color(0xFF242830); // Surface 2 – elevated / nested cards
  static const elevated    = Color(0xFF2E333C); // Surface 3 – overlay / modals

  // ── Borders ─────────────────────────────────────────────────────────────
  static const border      = Color(0xFF334155); // Outline
  static const borderHover = Color(0xFF475569); // Outline hover

  // ── Accent (Teal Blue — replaces violet) ────────────────────────────────
  static const accent      = Color(0xFF0A84FF); // Primary CTA
  static const accentDim   = Color(0xFF0070CC); // Dimmed primary
  static const accentMuted = Color(0xFF005799); // Muted primary

  // ── Text ────────────────────────────────────────────────────────────────
  static const ink         = Color(0xFFF1F5F9); // On Surface – primary text
  static const stone       = Color(0xFF94A3B8); // On Surface Variant – secondary text
  static const hint        = Color(0xFF64748B); // Tertiary text
  static const divider     = Color(0xFF334155); // Outline Variant

  // ── Semantic ────────────────────────────────────────────────────────────
  static const error       = Color(0xFFEF4444); // Bearish / destructive
  static const success     = Color(0xFF10B981); // Emerald – order filled, connection live
  static const warning     = Color(0xFFF59E0B); // Amber – margin calls, alerts

  // ── Trading Semantic (unique to Garuda Dark) ────────────────────────────
  static const bullish     = Color(0xFF22C55E); // Price up / gains
  static const bullishMuted = Color(0x2622C55E); // 15% opacity for chips
  static const bearish     = Color(0xFFEF4444); // Price down / losses (same as error)
  static const bearishMuted = Color(0x26EF4444); // 15% opacity for chips
  static const info        = Color(0xFF38BDF8); // Informational badges, links

  // ── Orb / decoration (shifted from violet to teal-blue) ─────────────────
  static const orbLight = Color(0x220A84FF); // ~13% teal-blue
  static const orbMid   = Color(0x1806B6D4); // ~9% cyan
}

/// Light-mode palette — Garuda Light
class AppColorsLight {
  AppColorsLight._();

  // ── Backgrounds ─────────────────────────────────────────────────────────
  static const canvas      = Color(0xFFF8FAFC); // Surface 0 – cool off-white
  static const surface     = Color(0xFFFFFFFF); // Surface 1 – pure white cards
  static const surfaceAlt  = Color(0xFFF1F5F9); // Surface 2 – nested elements
  static const elevated    = Color(0xFFE2E8F0); // Surface 3 – overlay

  // ── Borders ─────────────────────────────────────────────────────────────
  static const border      = Color(0xFFCBD5E1); // Outline
  static const borderHover = Color(0xFF94A3B8); // Outline hover

  // ── Accent ──────────────────────────────────────────────────────────────
  static const accent      = Color(0xFF0070E0); // Primary – deeper blue for contrast on white
  static const accentDim   = Color(0xFF005BB5);
  static const accentMuted = Color(0xFF004A8C);

  // ── Text ────────────────────────────────────────────────────────────────
  static const ink         = Color(0xFF0F172A); // On Surface – near-black
  static const stone       = Color(0xFF64748B); // On Surface Variant
  static const hint        = Color(0xFF94A3B8); // Tertiary text
  static const divider     = Color(0xFFE2E8F0); // Outline Variant

  // ── Semantic ────────────────────────────────────────────────────────────
  static const error       = Color(0xFFDC2626);
  static const success     = Color(0xFF059669);
  static const warning     = Color(0xFFD97706);

  // ── Trading Semantic ────────────────────────────────────────────────────
  static const bullish     = Color(0xFF16A34A); // Deeper green for light
  static const bullishMuted = Color(0x1A16A34A);
  static const bearish     = Color(0xFFDC2626);
  static const bearishMuted = Color(0x1ADC2626);
  static const info        = Color(0xFF0284C7);

  // ── Orb / decoration ────────────────────────────────────────────────────
  static const orbLight = Color(0x180070E0);
  static const orbMid   = Color(0x1406B6D4);
}

// ─── Adaptive helpers ────────────────────────────────────────────────────────

/// Returns the correct color pair based on current brightness.
class AppAdaptive {
  AppAdaptive._();

  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.canvas
          : AppColorsLight.canvas;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.surface
          : AppColorsLight.surface;

  static Color surfaceAlt(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceAlt
          : AppColorsLight.surfaceAlt;

  static Color elevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.elevated
          : AppColorsLight.elevated;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.border
          : AppColorsLight.border;

  static Color borderHover(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.borderHover
          : AppColorsLight.borderHover;

  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.accent
          : AppColorsLight.accent;

  static Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.ink
          : AppColorsLight.ink;

  static Color stone(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.stone
          : AppColorsLight.stone;

  static Color hint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.hint
          : AppColorsLight.hint;

  static Color orbLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.orbLight
          : AppColorsLight.orbLight;

  static Color orbMid(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.orbMid
          : AppColorsLight.orbMid;

  /// Glass tint — the semi-transparent overlay.
  static Color glassTint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.05);

  /// Glass border — subtle edge highlight.
  static Color glassBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.12)
          : Colors.black.withOpacity(0.08);

  // ── Trading semantic adaptives ──────────────────────────────────────────

  static Color bullish(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.bullish
          : AppColorsLight.bullish;

  static Color bearish(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.bearish
          : AppColorsLight.bearish;

  static Color success(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.success
          : AppColorsLight.success;

  static Color info(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.info
          : AppColorsLight.info;

  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.warning
          : AppColorsLight.warning;
}

// ─── Typography ──────────────────────────────────────────────────────────────

/// Garuda Dark typography scale.
///
/// Uses Inter for UI/body and JetBrains Mono for numeric displays.
/// All numeric displays should use tabular-nums lining-nums for column alignment.
class AppTextStyles {
  AppTextStyles._();

  // ── Inter (UI / Body) ─────────────────────────────────────────────────
  static const _base = TextStyle(
    fontFamily: 'Inter',
    leadingDistribution: TextLeadingDistribution.even,
  );

  // ── JetBrains Mono (Numeric / Data) ───────────────────────────────────
  static const _mono = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: ['SF Mono', 'Fira Code', 'monospace'],
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: [FontFeature.tabularFigures(), FontFeature.liningFigures()],
  );

  // ═══ Display (Hero Numbers — Mono) ═══
  static TextStyle display = _mono.copyWith(
    fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.2,
  );

  // ═══ Headlines ═══
  static TextStyle headline = _base.copyWith(
    fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.28, height: 1.3,
  );

  // ═══ Titles ═══
  static TextStyle title = _base.copyWith(
    fontSize: 20, fontWeight: FontWeight.w600, height: 1.35,
  );

  // ═══ Body Large ═══
  static TextStyle bodyLarge = _base.copyWith(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
  );

  // ═══ Body ═══
  static TextStyle body = _base.copyWith(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, letterSpacing: 0.14,
  );

  // ═══ Labels ═══
  static TextStyle label = _base.copyWith(
    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, height: 1.4,
  );

  // ═══ Captions ═══
  static TextStyle caption = _base.copyWith(
    fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.33, height: 1.4,
  );

  // ═══ Mono Display (Hero — JetBrains Mono) ═══
  static TextStyle monoDisplay = _mono.copyWith(
    fontSize: 36, fontWeight: FontWeight.w500, letterSpacing: -0.72, height: 1.2,
  );

  // ═══ Mono Body (Prices — JetBrains Mono) ═══
  static TextStyle monoBody = _mono.copyWith(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
  );

  // ═══ Mono Small (Chart Labels — JetBrains Mono) ═══
  static TextStyle monoSmall = _mono.copyWith(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.4,
  );
}

// ─── Theme ───────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build([Brightness brightness = Brightness.dark]) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? _DarkColors() : _LightColors();

    // ── ColorScheme aligned with Garuda Dark spec ────────────────────────
    final colorScheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF0A84FF),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFF0A84FF),
            onPrimaryContainer: Color(0xFFFFFFFF),
            secondary: Color(0xFF64748B),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFF1E293B),
            onSecondaryContainer: Color(0xFFCBD5E1),
            tertiary: Color(0xFFF59E0B), // Warning / Accent
            onTertiary: Color(0xFF000000),
            tertiaryContainer: Color(0xFF2E2306),
            onTertiaryContainer: Color(0xFFFCD34D),
            surface: Color(0xFF0F1114),
            onSurface: Color(0xFFF1F5F9),
            onSurfaceVariant: Color(0xFF94A3B8),
            error: Color(0xFFEF4444),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFF3B1111),
            onErrorContainer: Color(0xFFFCA5A5),
            outline: Color(0xFF334155),
            outlineVariant: Color(0xFF1E293B),
            shadow: Color(0xFF000000),
            scrim: Color(0xFF000000),
            inverseSurface: Color(0xFFF1F5F9),
            onInverseSurface: Color(0xFF0F1114),
            inversePrimary: Color(0xFF0A84FF),
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF0070E0),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFD6E8FF),
            onPrimaryContainer: Color(0xFF001C3A),
            secondary: Color(0xFF475569),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFE2E8F0),
            onSecondaryContainer: Color(0xFF1E293B),
            tertiary: Color(0xFFD97706),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFFFEF3C7),
            onTertiaryContainer: Color(0xFF78350F),
            surface: Color(0xFFF8FAFC),
            onSurface: Color(0xFF0F172A),
            onSurfaceVariant: Color(0xFF64748B),
            error: Color(0xFFDC2626),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFFEE2E2),
            onErrorContainer: Color(0xFF7F1D1D),
            outline: Color(0xFFCBD5E1),
            outlineVariant: Color(0xFFE2E8F0),
            shadow: Color(0xFF000000),
            scrim: Color(0xFF000000),
            inverseSurface: Color(0xFF1E293B),
            onInverseSurface: Color(0xFFF1F5F9),
            inversePrimary: Color(0xFF60A5FA),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: colorScheme,

      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0, scrolledUnderElevation: 0,
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: brightness,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: AppTextStyles.title.copyWith(
          fontSize: 16, color: colors.ink,
        ),
        iconTheme: IconThemeData(color: colors.ink, size: 22),
        actionsIconTheme: IconThemeData(color: colors.stone, size: 22),
      ),

      // ── Navigation Bar ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: colors.accent.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.ink : colors.hint,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.accent : colors.hint, size: 22,
          );
        }),
      ),

      // ── Elevated Button ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent, foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: AppTextStyles.label.copyWith(color: Colors.white),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: AppTextStyles.label.copyWith(color: colors.accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.accent,
          side: BorderSide(color: colors.accent),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: AppTextStyles.label.copyWith(color: colors.accent),
        ),
      ),

      // ── Input Decoration ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: colors.surfaceAlt,
        labelStyle: AppTextStyles.body.copyWith(color: colors.stone),
        hintStyle: AppTextStyles.body.copyWith(color: colors.hint),
        prefixIconColor: colors.hint, suffixIconColor: colors.hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Divider ───────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colors.border, thickness: 1, space: 1,
      ),

      // ── SnackBar ──────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.elevated,
        contentTextStyle: AppTextStyles.body.copyWith(color: colors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating, elevation: 0,
      ),

      // ── Chip ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceAlt,
        selectedColor: colors.accent.withOpacity(0.20),
        labelStyle: AppTextStyles.caption.copyWith(color: colors.ink),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── Text Theme ────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display.copyWith(color: colors.ink),
        displayMedium: AppTextStyles.monoDisplay.copyWith(color: colors.ink),
        headlineLarge: AppTextStyles.headline.copyWith(color: colors.ink),
        headlineMedium: AppTextStyles.headline.copyWith(fontSize: 24, color: colors.ink),
        titleLarge: AppTextStyles.title.copyWith(color: colors.ink),
        titleMedium: AppTextStyles.title.copyWith(fontSize: 16, color: colors.ink),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
        bodyMedium: AppTextStyles.body.copyWith(color: colors.ink),
        bodySmall: AppTextStyles.caption.copyWith(color: colors.stone),
        labelLarge: AppTextStyles.label.copyWith(color: colors.ink),
        labelMedium: AppTextStyles.label.copyWith(fontSize: 11, color: colors.stone),
      ),
    );
  }
}

// ─── Internal color holder (avoids repeating ternaries) ──────────────────────

abstract class _Colors {
  Color get canvas;
  Color get surface;
  Color get surfaceAlt;
  Color get elevated;
  Color get border;
  Color get borderHover;
  Color get accent;
  Color get ink;
  Color get stone;
  Color get hint;
  Color get error;
  Color get success;
  Color get warning;
  Color get bullish;
  Color get bearish;
  Color get info;
  Color get orbLight;
  Color get orbMid;
}

class _DarkColors implements _Colors {
  @override final canvas      = AppColors.canvas;
  @override final surface     = AppColors.surface;
  @override final surfaceAlt  = AppColors.surfaceAlt;
  @override final elevated    = AppColors.elevated;
  @override final border      = AppColors.border;
  @override final borderHover = AppColors.borderHover;
  @override final accent      = AppColors.accent;
  @override final ink         = AppColors.ink;
  @override final stone       = AppColors.stone;
  @override final hint        = AppColors.hint;
  @override final error       = AppColors.error;
  @override final success     = AppColors.success;
  @override final warning     = AppColors.warning;
  @override final bullish     = AppColors.bullish;
  @override final bearish     = AppColors.bearish;
  @override final info        = AppColors.info;
  @override final orbLight    = AppColors.orbLight;
  @override final orbMid      = AppColors.orbMid;
}

class _LightColors implements _Colors {
  @override final canvas      = AppColorsLight.canvas;
  @override final surface     = AppColorsLight.surface;
  @override final surfaceAlt  = AppColorsLight.surfaceAlt;
  @override final elevated    = AppColorsLight.elevated;
  @override final border      = AppColorsLight.border;
  @override final borderHover = AppColorsLight.borderHover;
  @override final accent      = AppColorsLight.accent;
  @override final ink         = AppColorsLight.ink;
  @override final stone       = AppColorsLight.stone;
  @override final hint        = AppColorsLight.hint;
  @override final error       = AppColorsLight.error;
  @override final success     = AppColorsLight.success;
  @override final warning     = AppColorsLight.warning;
  @override final bullish     = AppColorsLight.bullish;
  @override final bearish     = AppColorsLight.bearish;
  @override final info        = AppColorsLight.info;
  @override final orbLight    = AppColorsLight.orbLight;
  @override final orbMid      = AppColorsLight.orbMid;
}
