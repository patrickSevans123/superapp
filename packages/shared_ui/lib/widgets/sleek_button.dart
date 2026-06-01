import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aurora.dart' show AppAccent;

// ─── SleekButtonVariant ────────────────────────────────────────────────────

/// Variants for [SleekButton].
///
/// * `primary` – solid violet background
/// * `secondary` – surface-toned with border
/// * `ghost` – transparent
/// * `danger` – red tint
/// * `gradient` – violet → pink diagonal gradient (new)
enum SleekButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
  gradient,
}

// ─── SleekButton ───────────────────────────────────────────────────────────

/// A modern replacement for [GlassButton] with richer interaction and
/// styling options.
///
/// **New features** over [GlassButton]:
/// * `.gradient` constructor (violet → pink sweep)
/// * Loading state with subtle pulse animation
/// * Press animation: scale 0.96 + brightness shift
/// * Icon-only mode with circular shape
/// * Tighter letter-spacing, refined typography
///
/// Usage:
/// ```dart
/// // Primary
/// SleekButton(label: 'Submit', onPressed: () {});
///
/// // Gradient
/// SleekButton.gradient(label: 'Trade Now', onPressed: () {});
///
/// // Icon-only
/// SleekButton(icon: Icons.add, onPressed: () {}, iconOnly: true);
///
/// // Loading
/// SleekButton(label: 'Saving…', isLoading: true, onPressed: null);
/// ```
class SleekButton extends StatefulWidget {
  const SleekButton({
    super.key,
    this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = SleekButtonVariant.primary,
    this.small = false,
    this.iconOnly = false,
  })  : assert(label != null || icon != null,
            'SleekButton requires label, icon, or both'),
        _forceGradient = false;

  /// Gradient variant – violet → pink diagonal.
  const SleekButton.gradient({
    super.key,
    this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.small = false,
    this.iconOnly = false,
  })  : assert(label != null || icon != null,
            'SleekButton requires label, icon, or both'),
        variant = SleekButtonVariant.gradient,
        _forceGradient = true;

  final String? label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final SleekButtonVariant variant;
  final bool small;
  final bool iconOnly;
  final bool _forceGradient;

  @override
  State<SleekButton> createState() => _SleekButtonState();
}

class _SleekButtonState extends State<SleekButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  // ── Pulse animation for loading ───────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  bool get _disabled => widget.onPressed == null && !widget.isLoading;

  @override
  void initState() {
    super.initState();

    // Press animation
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );

    // Pulse animation for loading
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine),
    );

    if (widget.isLoading) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SleekButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Colours ───────────────────────────────────────────────────────────

  Color get _fgColor {
    if (_disabled) {
      return switch (widget.variant) {
        SleekButtonVariant.primary || SleekButtonVariant.gradient =>
            Colors.white.withOpacity(0.5),
        SleekButtonVariant.danger => AppColors.error.withOpacity(0.5),
        _ => AppColors.hint,
      };
    }
    return switch (widget.variant) {
      SleekButtonVariant.danger => AppColors.error,
      SleekButtonVariant.gradient => Colors.white,
      _ => Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.small ? 38.0 : 48.0;
    final fontSize = widget.small ? 12.0 : 13.0;
    final r = widget.small ? 10.0 : 12.0;
    final isCircular = widget.iconOnly;

    // Disable animations if user prefers reduced motion
    final disableAnim = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      onTapDown: _disabled ? null : (_) => _pressCtrl.forward(),
      onTapUp: _disabled
          ? null
          : (_) {
              _pressCtrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: _disabled ? null : () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_scale, if (!disableAnim) _pulse]),
        builder: (_, child) {
          final effectiveScale = disableAnim
              ? 1.0
              : _scale.value * (widget.isLoading ? _pulse.value : 1.0);
          return Transform.scale(scale: effectiveScale, child: child);
        },
        child: _buildInner(h, fontSize, r, isCircular),
      ),
    );
  }

  Widget _buildInner(double h, double fontSize, double r, bool isCircular) {
    final bool isGradient =
        widget.variant == SleekButtonVariant.gradient || widget._forceGradient;

    Color bgColor;
    Color? borderColor;
    Gradient? gradient;

    if (isGradient) {
      bgColor = Colors.transparent;
      gradient = const LinearGradient(
        colors: [AppColors.accent, AppAccent.pink],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
      borderColor = null;
    } else {
      switch (widget.variant) {
        case SleekButtonVariant.primary:
          bgColor = _disabled
              ? AppColors.accent.withOpacity(0.4)
              : AppColors.accent;
          borderColor = null;
        case SleekButtonVariant.secondary:
          bgColor = AppColors.elevated;
          borderColor = AppColors.borderHover;
        case SleekButtonVariant.ghost:
          bgColor = Colors.transparent;
          borderColor = null;
        case SleekButtonVariant.danger:
          bgColor = AppColors.error.withOpacity(_disabled ? 0.08 : 0.12);
          borderColor = AppColors.error.withOpacity(0.3);
        default:
          bgColor = AppColors.accent;
          borderColor = null;
      }
    }

    return SizedBox(
      width: isCircular ? h : null,
      height: h,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        padding: isCircular
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: widget.small ? 16 : 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(isCircular ? h / 2 : r),
          gradient: gradient,
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: _buildContent(fontSize),
      ),
    );
  }

  Widget _buildContent(double fontSize) {
    // Loading spinner
    if (widget.isLoading) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: widget.variant == SleekButtonVariant.danger
              ? AppColors.error
              : Colors.white,
        ),
      );
    }

    // Icon-only
    if (widget.iconOnly && widget.icon != null) {
      return Icon(widget.icon, size: widget.small ? 18 : 20, color: _fgColor);
    }

    // Icon + label
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon,
              size: widget.small ? 15 : 17, color: _fgColor),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label ?? '',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: _fgColor,
            letterSpacing: widget.small ? 0.0 : 0.3,
          ),
        ),
      ],
    );
  }
}
