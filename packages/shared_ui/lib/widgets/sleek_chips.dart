import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── SleekChip ─────────────────────────────────────────────────────────────

/// A sleek, rounded chip with optional remove icon.
///
/// ```dart
/// SleekChip('Fashion')
/// SleekChip('Trade', onRemoved: () {})
/// SleekChip('Active', accent: true)
/// ```
class SleekChip extends StatelessWidget {
  const SleekChip(
    this.label, {
    super.key,
    this.onRemoved,
    this.accent = false,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.small = false,
  });

  /// The label text.
  final String label;

  /// Called when the remove (×) icon is tapped.
  /// When non-null a small × button is shown on the trailing edge.
  final VoidCallback? onRemoved;

  /// If true the chip uses the accent colour scheme.
  final bool accent;

  /// Toggle selected state (when [onSelected] is provided).
  final bool selected;

  /// Selection callback – when provided the chip becomes togglable.
  final ValueChanged<bool>? onSelected;

  /// Optional leading icon.
  final IconData? icon;

  /// Compact variant (10 px shorter, tighter padding).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final isTappable = onSelected != null;

    final baseColor = accent ? AppColors.accent : AppColors.elevated;
    final borderColor = selected
        ? AppColors.accent.withOpacity(0.6)
        : accent
        ? AppColors.accent.withOpacity(0.30)
        : AppColors.borderHover;
    final bgColor = selected
        ? AppColors.accent.withOpacity(0.15)
        : accent
        ? AppColors.accent.withOpacity(0.08)
        : baseColor;
    final textColor = selected || accent ? AppColors.accent : AppColors.stone;

    Widget chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 10 : 14,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(small ? 12 : 16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 12 : 14, color: textColor),
            SizedBox(width: small ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
          if (onRemoved != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemoved,
              child: Icon(
                Icons.close_rounded,
                size: small ? 12 : 14,
                color: AppColors.hint,
              ),
            ),
          ],
        ],
      ),
    );

    if (isTappable) {
      return GestureDetector(onTap: () => onSelected!(!selected), child: chip);
    }

    return chip;
  }
}

// ─── PulseDot ──────────────────────────────────────────────────────────────

/// A small live-status indicator dot with a smooth pulsing animation.
///
/// ```dart
/// PulseDot(color: Colors.green)         // "market open"
/// PulseDot(color: AppColors.accent)     // "live"
/// PulseDot(color: Colors.amber, size: 6) // subtle warning
/// ```
///
/// Respects [MediaQuery.disableAnimations] – when true the dot renders
/// as a static circle (no pulse).
class PulseDot extends StatefulWidget {
  const PulseDot({
    super.key,
    this.color = AppColors.accent,
    this.size = 8.0,
    this.animate = true,
  });

  /// The base colour of the dot.
  final Color color;

  /// Diameter in logical pixels.
  final double size;

  /// Whether to animate the pulse.  Defaults to true.
  final bool animate;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations || !widget.animate;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final opacity = disable ? 1.0 : _pulse.value;
        final scale = disable ? 1.0 : (0.85 + 0.15 * _pulse.value);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.5),
              blurRadius: widget.size * 0.6,
              spreadRadius: widget.size * 0.2,
            ),
          ],
        ),
      ),
    );
  }
}
