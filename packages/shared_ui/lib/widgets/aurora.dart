import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── New Accent Colors ─────────────────────────────────────────────────────
/// Extended accent palette – merge into [AppColors] in app_theme.dart.
/// Kept separate here to avoid modifying the existing file.
class AppAccent {
  AppAccent._();

  // Module-specific accents
  static const Color cyan = Color(0xFF06B6D4); // cyan-500  – success / trade
  static const Color orange = Color(0xFFF97316); // orange-500 – warnings
  static const Color pink = Color(0xFFEC4899); // pink-500   – fashion module

  // Aurora mesh alpha layers (pre-multiplied for performance)
  static const Color auroraViolet = Color(0x338B5CF6); // ~20 % violet
  static const Color auroraPink = Color(0x22EC4899); // ~13 % pink
  static const Color auroraCyan = Color(0x2206B6D4); // ~13 % cyan
}

// ─── MeshOrb ───────────────────────────────────────────────────────────────

/// A single soft-light orb for the aurora mesh background.
///
/// Renders a coloured circle intended to be layered behind a
/// [BackdropFilter] blur so it appears as a diffuse glow.
class MeshOrb extends StatelessWidget {
  const MeshOrb({
    super.key,
    this.size = 300,
    this.color = AppAccent.auroraViolet,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// ─── AuroraMeshBackground ──────────────────────────────────────────────────

/// An animated aurora mesh background that replaces the static
/// [GradientBackground].
///
/// Renders **4** drifting orbs (violet, pink, cyan, violet-soft) on a
/// canvas-coloured backdrop with a global 90 px gaussian blur on top.
///
/// Orbs drift organically via sine/cosine at different frequencies so the
/// composition never visually repeats during the 12 s cycle.
///
/// Usage:
/// ```dart
/// AuroraMeshBackground(
///   child: SafeArea(child: myContent),
/// )
/// ```
///
/// Respects [MediaQuery.disableAnimations] – when true the orbs are
/// omitted entirely for accessibility.
class AuroraMeshBackground extends StatefulWidget {
  const AuroraMeshBackground({
    super.key,
    this.child,
    this.intensity = 1.0,
    this.speed = 1.0,
  });

  /// Foreground content placed above the blur layer.
  final Widget? child;

  /// Overall intensity multiplier (1.0 = default orb sizes / spreads).
  /// Range 0.0 … 1.5.  Values >1.0 increase glow aggressiveness.
  final double intensity;

  /// Animation speed multiplier.  1.0 = full 12 s cycle.
  final double speed;

  @override
  State<AuroraMeshBackground> createState() => _AuroraMeshBackgroundState();
}

class _AuroraMeshBackgroundState extends State<AuroraMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (12000 / widget.speed).round()),
    )..repeat();
  }

  @override
  void didUpdateWidget(AuroraMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _controller.duration =
          Duration(milliseconds: (12000 / widget.speed).round());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations;
    final i = widget.intensity.clamp(0.0, 1.5);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base canvas
        Container(color: AppColors.canvas),

        // Animated orbs – skipped when animations disabled
        if (!disable)
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = _controller.value * 2 * math.pi;
              return _buildOrbs(t, i);
            },
          ),

        // Global blur – always present so the static fallback still looks
        // decent when animations are off
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
            child: const SizedBox.expand(),
          ),
        ),

        // Foreground content
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _buildOrbs(double t, double i) {
    // Orb 0 – violet, top-left, slow drift
    // Orb 1 – pink, bottom-right, medium drift
    // Orb 2 – cyan, mid-right, faster drift
    // Orb 3 – warm violet, bottom-left, cross-drift

    final orbs = <Widget>[
      _orbAt(
        xFrac: 0.15 + 0.12 * math.sin(t * 0.7),
        yFrac: 0.10 + 0.12 * math.cos(t * 0.5),
        size: 320 * i,
        color: AppAccent.auroraViolet,
      ),
      _orbAt(
        xFrac: 0.78 + 0.14 * math.sin(t * 0.5 + 1.2),
        yFrac: 0.75 + 0.12 * math.cos(t * 0.7 + 1.2),
        size: 360 * i,
        color: AppAccent.auroraPink,
      ),
      _orbAt(
        xFrac: 0.50 + 0.18 * math.sin(t * 0.3 + 2.5),
        yFrac: 0.28 + 0.16 * math.cos(t * 0.6 + 2.5),
        size: 280 * i,
        color: AppAccent.auroraCyan,
      ),
      _orbAt(
        xFrac: 0.05 + 0.14 * math.sin(t * 0.9 + 0.8),
        yFrac: 0.80 + 0.12 * math.cos(t * 0.4 + 0.8),
        size: 250 * i,
        color: AppAccent.auroraViolet.withOpacity(0.15 * i),
      ),
    ];

    return Stack(children: orbs);
  }

  Widget _orbAt({
    required double xFrac,
    required double yFrac,
    required double size,
    required Color color,
  }) {
    return Positioned(
      left: xFrac * MediaQuery.of(context).size.width - size / 2,
      top: yFrac * MediaQuery.of(context).size.height - size / 2,
      child: MeshOrb(size: size, color: color),
    );
  }
}


