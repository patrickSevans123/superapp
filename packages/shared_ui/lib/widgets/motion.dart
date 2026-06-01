import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ANIMATION CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

/// Centralised motion constants for the design system.
///
/// Use these instead of raw `Duration` or `Curves` literals across the app
/// to keep animations consistent and easy to tweak.
class AppMotion {
  AppMotion._();

  // ── Durations ──────────────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration page = Duration(milliseconds: 350);

  // ── Curves ─────────────────────────────────────────────────────────────
  /// Smooth ease-in-out for shared transitions.
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Snappy deceleration for enter animations.
  static const Curve standard = Curves.easeOutCubic;

  /// Gentle deceleration for exit / dismiss animations.
  static const Curve decelerate = Curves.easeOutQuart;

  /// Subtle overshoot for playful moments (e.g. counter bounces).
  static const Curve spring = Curves.easeOutBack;
}

/// Pre-built shadow levels.
///
/// Apply as `boxShadow: AppShadows.md` in your [BoxDecoration].
class AppShadows {
  AppShadows._();

  static const BoxShadow xs = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );
  static const BoxShadow sm = BoxShadow(
    color: Color(0x0C000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const BoxShadow md = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const BoxShadow lg = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  static const BoxShadow xl = BoxShadow(
    color: Color(0x18000000),
    blurRadius: 48,
    offset: Offset(0, 16),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  PAGE TRANSITIONS
// ═══════════════════════════════════════════════════════════════════════════

/// Shared-axis horizontal transition (ideal for tab switches).
///
/// Slides the incoming page from the side while fading.
///
/// ```dart
/// SharedAxisHorizontalTransition(
///   animation: animation,
///   child: child,
///   primary: isForward,
/// )
/// ```
///
/// Respects [MediaQuery.disableAnimations].
class SharedAxisHorizontalTransition extends StatelessWidget {
  const SharedAxisHorizontalTransition({
    super.key,
    required this.animation,
    required this.child,
    this.primary,
  });

  final Animation<double> animation;
  final Widget child;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations;
    if (disable) return child;

    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      reverseCurve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );
    final slide = Tween<Offset>(
      begin: Offset(primary == true ? 0.08 : -0.08, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Shared-axis vertical transition (ideal for drill-down navigation).
///
/// Slides the incoming page upward while fading.
///
/// ```dart
/// SharedAxisVerticalTransition(
///   animation: animation,
///   child: child,
///   primary: isPush,
/// )
/// ```
///
/// Respects [MediaQuery.disableAnimations].
class SharedAxisVerticalTransition extends StatelessWidget {
  const SharedAxisVerticalTransition({
    super.key,
    required this.animation,
    required this.child,
    this.primary,
  });

  final Animation<double> animation;
  final Widget child;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations;
    if (disable) return child;

    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );
    final slide = Tween<Offset>(
      begin: Offset(0, primary == true ? 0.06 : -0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PAGE TRANSITION HELPER
// ═══════════════════════════════════════════════════════════════════════════

/// Static helper for constructing page transitions.
///
/// Works alongside the existing [SleekPageTransition] from `glass.dart`.
/// Use these inside your `PageRouteBuilder`:
///
/// ```dart
/// MaterialPageRoute(
///   builder: (_) => DetailPage(),
///   transitionsBuilder: (ctx, anim, _, child) =>
///       PageTransition.vertical(animation: anim, child: child, primary: true),
/// )
/// ```
class PageTransition {
  PageTransition._();

  /// Shared-axis horizontal transition.
  static Widget horizontal({
    required Animation<double> animation,
    required Widget child,
    bool? primary,
  }) {
    return SharedAxisHorizontalTransition(
      animation: animation,
      child: child,
      primary: primary,
    );
  }

  /// Shared-axis vertical transition.
  static Widget vertical({
    required Animation<double> animation,
    required Widget child,
    bool? primary,
  }) {
    return SharedAxisVerticalTransition(
      animation: animation,
      child: child,
      primary: primary,
    );
  }
}
