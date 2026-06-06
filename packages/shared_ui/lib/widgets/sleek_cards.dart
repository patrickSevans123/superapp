import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aurora.dart' show AppAccent;
import 'motion.dart' show AppMotion, AppShadows;

// ═══════════════════════════════════════════════════════════════════════════
//  GLASS CARD  (Extended)
// ═══════════════════════════════════════════════════════════════════════════

/// A pressable glassmorphism card with four variants.
///
/// **Variant comparison:**
///
/// | Constructor       | Shadow | Border glow | Gradient fill         | Uses mesh colours |
/// |-------------------|--------|-------------|-----------------------|-------------------|
/// | `GlassCard()`     | –      | –           | –                     | –                 |
/// | `.elevated`       | ✅ md  | ✅ on hover | –                     | –                 |
/// | `.gradient`       | –      | –           | ✅ violet→pink        | –                 |
/// | `.aurora`         | ✅ sm  | –           | –                     | ✅ picks up mesh  |
///
/// Usage:
/// ```dart
/// // Flat (classic)
/// GlassCard(child: Text('Hello'))
///
/// // Elevated with shadow + hover glow
/// GlassCard.elevated(
///   child: Text('Balance: Rp 2.4 M'),
///   onTap: () {},
/// )
///
/// // Gradient fill
/// GlassCard.gradient(
///   child: Text('Fashion Week'),
///   gradient: LinearGradient(colors: [violet, pink]),
/// )
///
/// // Aurora-tinted
/// GlassCard.aurora(
///   child: Text('Portfolio'),
/// )
/// ```
class GlassCard extends StatefulWidget {
  // ── Flat (original behaviour) ──────────────────────────────────────────
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 12.0,
    this.padding,
    this.margin,
    this.onTap,
  })  : elevation = 0,
        gradient = null,
        borderGlow = false,
        auroraColors = null;

  // ── Elevated ───────────────────────────────────────────────────────────
  const GlassCard.elevated({
    super.key,
    required this.child,
    this.radius = 12.0,
    this.padding,
    this.margin,
    this.onTap,
  })  : elevation = 3,
        gradient = null,
        borderGlow = true,
        auroraColors = null;

  // ── Gradient ───────────────────────────────────────────────────────────
  const GlassCard.gradient({
    super.key,
    required this.child,
    this.radius = 12.0,
    this.padding,
    this.margin,
    this.onTap,
    required this.gradient,
  })  : elevation = 0,
        borderGlow = false,
        auroraColors = null;

  // ── Aurora ─────────────────────────────────────────────────────────────
  const GlassCard.aurora({
    super.key,
    required this.child,
    this.radius = 12.0,
    this.padding,
    this.margin,
    this.onTap,
    this.auroraColors,
  })  : elevation = 1,
        gradient = null,
        borderGlow = false;

  // ── Fields ────────────────────────────────────────────────────────────
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final int elevation;
  final Gradient? gradient;
  final bool borderGlow;
  final List<Color>? auroraColors;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  // Hover glow
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      reverseDuration: AppMotion.normal,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: AppMotion.standard),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Color get _borderColor {
    if (_hovered && widget.borderGlow) return AppColors.accent.withOpacity(0.5);
    // Default glass border — light alpha so it reads as an edge highlight
    // on top of the [BackdropFilter] blur.  The `withOpacity` value is
    // tuned per-theme in [build] but we fall back to a neutral value here
    // for callers that read this getter outside the build context.
    return Colors.white.withOpacity(0.18);
  }

  List<BoxShadow> get _shadows {
    if (widget.elevation <= 0) return const [];
    return switch (widget.elevation) {
      1 => [AppShadows.xs, AppShadows.sm],
      2 => [AppShadows.sm, AppShadows.md],
      3 => [AppShadows.md, AppShadows.lg],
      _ => [AppShadows.md],
    };
  }

  /// Returns the aurora-derived gradient when [auroraColors] is set.
  Gradient? get _auroraGradient {
    if (widget.auroraColors != null && widget.auroraColors!.length >= 2) {
      return LinearGradient(
        colors: widget.auroraColors!,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // Default aurora palette
    if (widget.auroraColors != null) {
      return const LinearGradient(
        colors: [AppAccent.auroraViolet, AppAccent.auroraPink, AppAccent.auroraCyan],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.of(context).disableAnimations;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Theme-aware glass palette ────────────────────────────────────
    // The CSS spec uses white-tinted glass; we keep the same hue and just
    // dial opacity up for light mode (so the card stands out from a
    // bright aurora wash) and down for dark mode (so it doesn't blow out).
    final glassFill = widget.gradient != null || _auroraGradient != null
        ? Colors.transparent
        : (isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.35));
    final glassBorder = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.white.withOpacity(0.45);
    final edgeHighlight = isDark
        ? Colors.white.withOpacity(0.45)
        : Colors.white.withOpacity(0.85);
    final dropShadow = isDark
        ? Colors.black.withOpacity(0.35)
        : Colors.black.withOpacity(0.10);
    final innerGlow = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.45);

    // ── Visual layer: shape + tint | gradient + multi-shadow ─────────
    Widget visual = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: glassFill,
        gradient: widget.gradient ?? _auroraGradient,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: _hovered && widget.borderGlow
              ? AppColors.accent.withOpacity(0.55)
              : glassBorder,
          width: _hovered && widget.borderGlow ? 1.5 : 1.0,
        ),
        boxShadow: [
          // Drop shadow (CSS: 0 8px 32px rgba(0,0,0,0.10))
          BoxShadow(
            color: dropShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          // Inset glow (CSS: inset 0 0 10px 5px rgba(255,255,255,0.5))
          BoxShadow(
            color: innerGlow,
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
          // Elevation shadows (from the original `elevation` field)
          ..._shadows,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Stack(
          children: [
            // ── Content ─────────────────────────────────────────────
            if (widget.padding != null)
              Padding(padding: widget.padding!, child: widget.child)
            else
              widget.child,

            // ── ::before — top edge highlight (1px gradient) ───────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        edgeHighlight,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── ::after — left edge highlight (1px gradient) ────────
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        edgeHighlight,
                        Colors.transparent,
                        edgeHighlight.withOpacity(
                          edgeHighlight.opacity * 0.4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ── Wrap in press handler ────────────────────────────────────────
    if (widget.onTap != null) {
      visual = GestureDetector(
        onTapDown: disableAnim ? null : (_) => _pressCtrl.forward(),
        onTapUp: disableAnim
            ? null
            : (_) {
                _pressCtrl.reverse();
                widget.onTap?.call();
              },
        onTapCancel: disableAnim ? null : () => _pressCtrl.reverse(),
        child: visual,
      );
    }

    // ── Wrap in scale animation ──────────────────────────────────────
    if (!disableAnim && widget.onTap != null) {
      visual = AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: visual,
      );
    }

    // ── Wrap in hover detector (desktop border glow) ─────────────────
    if (widget.borderGlow) {
      visual = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: visual,
      );
    }

    // ── Final wrap: transparent Material → ClipRRect → BackdropFilter
    //
    // The Material(transparency) gives [ListTile] / [InkWell] /
    // [SwitchListTile] descendants a proper Material ancestor to paint
    // their ink splashes on (otherwise the Container's gradient absorbs
    // the ink and Flutter throws "ListTile background color or ink
    // splashes may be invisible.").  `MaterialType.transparency` paints
    // nothing of its own.
    //
    // The BackdropFilter is what actually makes this glassmorphism: it
    // blurs the area *behind* the card (the aurora orbs, the page
    // background, anything scrolling past) by 17px — the same `blur(17px)`
    // in the CSS spec.  One BackdropFilter per card is more expensive
    // than a single root-level blur, but it's the only way to get the
    // true frosted-glass look for individual cards.
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 17, sigmaY: 17),
          child: visual,
        ),
      ),
    );
  }
}
