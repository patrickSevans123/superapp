import 'dart:math' as math;
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

  Color get _surfaceColor => AppColors.surface;

  Color get _borderColor {
    if (_hovered && widget.borderGlow) return AppColors.accent.withOpacity(0.5);
    return AppColors.border;
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

    Widget card = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.gradient != null || _auroraGradient != null
            ? null
            : _surfaceColor,
        gradient: widget.gradient ?? _auroraGradient,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: _borderColor, width: _hovered ? 1.5 : 1.0),
        boxShadow: _shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: widget.padding != null
            ? Padding(padding: widget.padding!, child: widget.child)
            : widget.child,
      ),
    );

    // Wrap in press handler
    if (widget.onTap != null) {
      card = GestureDetector(
        onTapDown: disableAnim ? null : (_) => _pressCtrl.forward(),
        onTapUp: disableAnim
            ? null
            : (_) {
                _pressCtrl.reverse();
                widget.onTap?.call();
              },
        onTapCancel: disableAnim ? null : () => _pressCtrl.reverse(),
        child: card,
      );
    }

    // Wrap in scale animation
    if (!disableAnim && widget.onTap != null) {
      card = AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: card,
      );
    }

    // Wrap in hover detector (desktop border glow)
    if (widget.borderGlow) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: card,
      );
    }

    return card;
  }
}
