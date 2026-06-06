import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/pin/pin_provider.dart';

/// Full-screen PIN input with glassmorphism styling.
///
/// Used both for app-lock verification and for initial PIN setup.
class PinInputScreen extends ConsumerStatefulWidget {
  /// When `true` the screen is in "set new PIN" mode (no verification
  /// against a stored PIN — just saves the entered code).
  final bool setupMode;

  const PinInputScreen({super.key, this.setupMode = false});

  @override
  ConsumerState<PinInputScreen> createState() => _PinInputScreenState();
}

class _PinInputScreenState extends ConsumerState<PinInputScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(int digit) {
    HapticFeedback.lightImpact();
    ref.read(pinInputProvider.notifier).onDigit(digit);
  }

  void _onBackspace() {
    HapticFeedback.mediumImpact();
    ref.read(pinInputProvider.notifier).onBackspace();
  }

  void _onSubmit() {
    final notifier = ref.read(pinInputProvider.notifier);
    if (widget.setupMode) {
      notifier.save();
    } else {
      notifier.verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinInputProvider);

    // Shake on error.
    if (state.error != null && !_shakeController.isAnimating) {
      _shakeController.forward(from: 0);
    }

    // On success, pop with result.
    ref.listen<PinInputState>(pinInputProvider, (prev, next) {
      if (next.success && mounted) {
        Navigator.of(context).pop(true);
      }
    });

    final pinLength = ref.read(pinInputProvider.notifier).pinLength;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Header ──
                  Icon(
                    widget.setupMode
                        ? Icons.lock_outline_rounded
                        : Icons.lock_rounded,
                    size: 64,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.setupMode ? 'Create a PIN' : 'Enter your PIN',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.setupMode
                        ? 'This PIN will be required each time you open the app.'
                        : 'Enter the PIN to unlock the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.stone,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── PIN dots ──
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final shake =
                          (_shakeAnimation.value * 8 - 4) *
                              (state.error != null ? 1 : 0);
                      return Transform.translate(
                        offset: Offset(shake, 0),
                        child: child,
                      );
                    },
                    child: _PinDots(
                      length: pinLength,
                      filled: state.entered.length,
                      error: state.error != null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Error text ──
                  SizedBox(
                    height: 24,
                    child: state.error != null
                        ? Text(
                            state.error!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 48),

                  // ── Numpad ──
                  _Numpad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    onSubmit: _onSubmit,
                    showSubmit: state.entered.length == pinLength,
                  ),

                  const SizedBox(height: 32),

                  // ── Loading indicator ──
                  if (state.verifying)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── PIN Dots ──────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;

  const _PinDots({
    required this.length,
    required this.filled,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: error
                  ? AppColors.error
                  : isFilled
                      ? AppColors.accent
                      : Colors.transparent,
              border: Border.all(
                color: error
                    ? AppColors.error
                    : isFilled
                        ? AppColors.accent
                        : AppAdaptive.glassBorder(context),
                width: 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool showSubmit;

  const _Numpad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.showSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NumpadRow(
          digits: const [1, 2, 3],
          onDigit: onDigit,
        ),
        const SizedBox(height: 12),
        _NumpadRow(
          digits: const [4, 5, 6],
          onDigit: onDigit,
        ),
        const SizedBox(height: 12),
        _NumpadRow(
          digits: const [7, 8, 9],
          onDigit: onDigit,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72),
            _NumpadKey(
              digit: 0,
              onTap: () => onDigit(0),
            ),
            _ActionKey(
              icon: showSubmit ? Icons.check_rounded : Icons.backspace_outlined,
              onTap: showSubmit ? onSubmit : onBackspace,
              isSubmit: showSubmit,
            ),
          ],
        ),
      ],
    );
  }
}

class _NumpadRow extends StatelessWidget {
  final List<int> digits;
  final ValueChanged<int> onDigit;

  const _NumpadRow({required this.digits, required this.onDigit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _NumpadKey(
                digit: d,
                onTap: () => onDigit(d),
              ))
          .toList(),
    );
  }
}

class _NumpadKey extends StatelessWidget {
  final int digit;
  final VoidCallback onTap;

  const _NumpadKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppAdaptive.glassTint(context),
          border: Border.all(color: AppAdaptive.glassBorder(context)),
        ),
        child: Center(
          child: Text(
            '$digit',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isSubmit;

  const _ActionKey({
    required this.icon,
    required this.onTap,
    this.isSubmit = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSubmit ? AppColors.accent : Colors.transparent,
          border: isSubmit ? null : Border.all(color: Colors.transparent),
        ),
        child: Icon(
          icon,
          size: 28,
          color: isSubmit ? Colors.white : AppColors.ink,
        ),
      ),
    );
  }
}
