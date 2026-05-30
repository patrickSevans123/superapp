import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Background ──────────────────────────────────────────────────────────────

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.canvas),
        Positioned(
          top: -100, right: -100,
          child: Container(
            width: 320, height: 320,
            decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.orbLight,
            ),
          ),
        ),
        Positioned(
          bottom: -120, left: -120,
          child: Container(
            width: 380, height: 380,
            decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.orbMid,
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
            child: const SizedBox.expand(),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

// ─── GlassScaffold ───────────────────────────────────────────────────────────

class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key, required this.body,
    this.appBar, this.floatingActionButton, this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false, this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: body,
    );
  }
}

// ─── GlassBox ────────────────────────────────────────────────────────────────

class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key, required this.child,
    this.radius = 14.0, this.padding, this.margin,
    this.blur = 0, this.shadow = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: shadow
            ? [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

// ─── GlassCard (press animation) ─────────────────────────────────────────────

class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key, required this.child,
    this.radius = 12.0, this.padding, this.margin, this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120), reverseDuration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: widget.padding != null ? Padding(padding: widget.padding!, child: widget.child) : widget.child,
          ),
        ),
      ),
    );
  }
}

// ─── GlassButton ─────────────────────────────────────────────────────────────

enum GlassButtonVariant { primary, secondary, ghost, danger }

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key, required this.label, required this.onPressed,
    this.icon, this.isLoading = false, this.variant = GlassButtonVariant.primary, this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final GlassButtonVariant variant;
  final bool small;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool get _disabled => widget.onPressed == null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), reverseDuration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _fgColor {
    if (_disabled) {
      return switch (widget.variant) {
        GlassButtonVariant.primary => Colors.white.withOpacity(0.5),
        GlassButtonVariant.danger  => AppColors.error.withOpacity(0.5),
        _                          => AppColors.hint,
      };
    }
    return switch (widget.variant) {
      GlassButtonVariant.danger => AppColors.error,
      _                         => Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.small ? 38.0 : 48.0;
    final fontSize = widget.small ? 12.0 : 13.0;
    final r = widget.small ? 10.0 : 12.0;

    Color bgColor;
    Color? borderColor;
    switch (widget.variant) {
      case GlassButtonVariant.primary:   bgColor = _disabled ? AppColors.accent.withOpacity(0.4) : AppColors.accent; borderColor = null;
      case GlassButtonVariant.secondary: bgColor = AppColors.elevated; borderColor = AppColors.borderHover;
      case GlassButtonVariant.ghost:     bgColor = Colors.transparent; borderColor = null;
      case GlassButtonVariant.danger:    bgColor = AppColors.error.withOpacity(_disabled ? 0.08 : 0.12); borderColor = AppColors.error.withOpacity(0.3);
    }

    return GestureDetector(
      onTapDown: _disabled ? null : (_) => _ctrl.forward(),
      onTapUp: _disabled ? null : (_) { _ctrl.reverse(); widget.onPressed?.call(); },
      onTapCancel: _disabled ? null : () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          height: h,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: widget.small ? 16 : 20),
            decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(r),
              border: borderColor != null ? Border.all(color: borderColor) : null,
            ),
            child: widget.isLoading
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: widget.variant == GlassButtonVariant.primary ? Colors.white : AppColors.accent))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[Icon(widget.icon, size: widget.small ? 15 : 17, color: _fgColor), SizedBox(width: widget.small ? 6 : 8)],
                      Text(widget.label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: _fgColor, letterSpacing: -0.1)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── GlassTextField ──────────────────────────────────────────────────────────

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key, this.controller, this.hintText, this.label,
    this.prefixIcon, this.suffixIcon, this.obscureText = false,
    this.keyboardType, this.validator, this.onChanged,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller, obscureText: obscureText, keyboardType: keyboardType,
      validator: validator, onChanged: onChanged,
      style: AppTextStyles.body.copyWith(color: AppColors.ink),
      cursorColor: AppColors.accent, cursorWidth: 1.5,
      decoration: InputDecoration(
        labelText: label, hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.hint),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.stone),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.hint) : null,
        suffixIcon: suffixIcon,
        filled: true, fillColor: AppColors.elevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── GlassAppBar ─────────────────────────────────────────────────────────────

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, this.title, this.titleWidget, this.leading, this.actions, this.centerTitle = false});

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!, style: AppTextStyles.title.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)) : null),
      leading: leading, actions: actions, centerTitle: centerTitle,
      backgroundColor: AppColors.canvas, elevation: 0, scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.ink),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.border)),
    );
  }
}

// ─── GlassDivider ────────────────────────────────────────────────────────────

class GlassDivider extends StatelessWidget {
  const GlassDivider({super.key, this.label, this.vertical = false});
  final String? label;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) return Container(width: 1, color: AppColors.border);
    if (label != null) {
      return Row(children: [
        Expanded(child: Container(height: 1, color: AppColors.border)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(label!, style: AppTextStyles.caption.copyWith(color: AppColors.hint))),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ]);
    }
    return Container(height: 1, color: AppColors.border);
  }
}

// ─── GlassBadge ──────────────────────────────────────────────────────────────

class GlassBadge extends StatelessWidget {
  const GlassBadge(this.label, {super.key, this.accent = false});
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? AppColors.accent.withOpacity(0.15) : AppColors.elevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent ? AppColors.accent.withOpacity(0.30) : AppColors.borderHover),
      ),
      child: Text(label.toUpperCase(), style: AppTextStyles.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: accent ? AppColors.accent : AppColors.stone), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

// ─── GlassFieldLabel ──────────────────────────────────────────────────────────

class GlassFieldLabel extends StatelessWidget {
  const GlassFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.hint,
        fontSize: 11,
      ),
    );
  }
}

// ─── SleekPageTransition ─────────────────────────────────────────────────────

class SleekPageTransition extends StatelessWidget {
  const SleekPageTransition({super.key, required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    final slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
  }
}
