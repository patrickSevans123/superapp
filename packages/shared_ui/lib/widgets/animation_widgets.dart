import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aurora.dart' show AppAccent;

// ─── ShimmerPlaceholder ────────────────────────────────────────────────────

/// A loading placeholder with a purple→pink gradient sweep.
///
/// ```dart
/// // Simple rectangle
/// ShimmerPlaceholder(width: 120, height: 16, borderRadius: 4)
///
/// // Circular avatar
/// ShimmerPlaceholder(size: 48, borderRadius: 24)
///
/// // Full-width row
/// Row(children: [
///   ShimmerPlaceholder(size: 40, borderRadius: 20),
///   SizedBox(width: 12),
///   Expanded(child: ShimmerPlaceholder(height: 16, borderRadius: 4)),
/// ])
/// ```
///
/// Respects [MediaQuery.disableAnimations] – renders a static dark
/// placeholder when animations are disabled.
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.size,
    this.borderRadius = 8.0,
    this.margin,
    this.baseColor = const Color(0xFF27272A), // zinc-800
  }) : assert(width == null || height == null || size == null,
            'Provide width+height, or size for a square placeholder');

  /// Width of the placeholder (ignored when [size] is set).
  final double? width;

  /// Height of the placeholder (ignored when [size] is set).
  final double? height;

  /// When set, creates a square placeholder of this size.
  final double? size;

  /// Corner radius.
  final double borderRadius;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Base background colour.  The shimmer highlight is layered on top.
  final Color baseColor;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _sweep = Tween<double>(begin: -0.4, end: 1.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size ?? widget.width;
    final h = widget.size ?? widget.height;

    final disable = MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final pos = _sweep.value;

        return Container(
          width: w,
          height: h,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: disable
                ? LinearGradient(colors: [widget.baseColor, widget.baseColor])
                : LinearGradient(
                    colors: const [
                      Color(0xFF27272A), // zinc-800 – base dark
                      Color(0xFF4C1D95), // violet-900 – approach
                      Color(0xFF8B5CF6), // violet-500 – peak
                      Color(0xFFEC4899), // pink-500   – tail
                      Color(0xFF27272A), // back to base
                    ],
                    stops: [
                      0.0,
                      (pos - 0.25).clamp(0.0, 1.0),
                      (pos).clamp(0.0, 1.0),
                      (pos + 0.20).clamp(0.0, 1.0),
                      1.0,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ─── NumberCounter ─────────────────────────────────────────────────────────

/// An animated count-up widget for statistics (portfolio value, scholarship
/// counts, follower counts, etc.).
///
/// ```dart
/// NumberCounter(
///   target: 1247,
///   duration: Duration(milliseconds: 800),
///   style: AppTextStyles.display,
/// )
/// ```
///
/// Animates from the previous value to the new [target] whenever the target
/// changes.  Uses [Curves.easeOutQuart] for a natural deceleration.
class NumberCounter extends StatefulWidget {
  const NumberCounter({
    super.key,
    required this.target,
    this.duration = const Duration(milliseconds: 700),
    this.style,
    this.textAlign = TextAlign.center,
    this.formatter,
    this.prefix,
    this.suffix,
  });

  /// The final number to count up to.
  final int target;

  /// Duration of the count-up animation.
  final Duration duration;

  /// Optional text style.  Defaults to [AppTextStyles.headline].
  final TextStyle? style;

  /// Text alignment.
  final TextAlign textAlign;

  /// Optional formatter for display (e.g. currency formatting, comma
  /// separators).  Receives the current integer value.
  final String Function(int value)? formatter;

  /// Optional prefix widget (e.g. a currency symbol).
  final Widget? prefix;

  /// Optional suffix widget (e.g. "pts", "IDR").
  final Widget? suffix;

  @override
  State<NumberCounter> createState() => _NumberCounterState();
}

class _NumberCounterState extends State<NumberCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<int> _count;
  int _prev = 0;

  @override
  void initState() {
    super.initState();
    _prev = 0;
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _count = IntTween(begin: 0, end: widget.target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(NumberCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _prev = oldWidget.target;
      _ctrl.duration = widget.duration;
      _count = IntTween(begin: _prev, end: widget.target).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart),
      );
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations;
    final displayValue = disable ? widget.target : _count.value;
    final formatted = widget.formatter?.call(displayValue) ?? _formatInt(displayValue);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.prefix != null) widget.prefix!,
        AnimatedBuilder(
          animation: _count,
          builder: (_, __) {
            return Text(
              formatted,
              style: widget.style ?? AppTextStyles.headline,
              textAlign: widget.textAlign,
            );
          },
        ),
        if (widget.suffix != null) widget.suffix!,
      ],
    );
  }

  String _formatInt(int n) {
    // Indonesian-style thousands separator (.)
    if (n >= 1000) {
      final str = n.toString();
      final buf = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
        buf.write(str[i]);
      }
      return buf.toString();
    }
    return n.toString();
  }
}

// ─── StaggeredListItem ─────────────────────────────────────────────────────

/// A list item that fades in and slides up with a staggered delay.
///
/// ```dart
/// ListView.builder(
///   itemBuilder: (ctx, i) => StaggeredListItem(
///     index: i,
///     child: GlassCard(child: ListTile(...)),
///   ),
/// )
/// ```
///
/// Each successive item starts its animation 60 ms after the previous one.
/// Items use [Curves.easeOutCubic] for a premium, snappy feel.
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 50),
  });

  /// The zero-based index in the list.  Delay = `index * baseDelay`.
  final int index;

  /// The widget to animate in.
  final Widget child;

  /// Per-item stagger increment.  Default 50 ms → item 4 starts at 200 ms.
  final Duration baseDelay;

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final stagger = widget.baseDelay * widget.index;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    // Staggered start
    Future.delayed(stagger, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations;

    if (disable) return widget.child;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
