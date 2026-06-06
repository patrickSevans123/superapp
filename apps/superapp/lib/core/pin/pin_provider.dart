import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';
import 'pin_service.dart';

/// Provides the [PinService] instance.
final pinServiceProvider = Provider<PinService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return PinService(storage);
});

/// Whether PIN lock is currently enabled.
final pinEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(pinServiceProvider);
  return service.isPinEnabled();
});

/// State for the PIN input flow.
class PinInputState {
  final String entered;
  final bool verifying;
  final String? error;
  final bool success;

  const PinInputState({
    this.entered = '',
    this.verifying = false,
    this.error,
    this.success = false,
  });

  PinInputState copyWith({
    String? entered,
    bool? verifying,
    String? error,
    bool? success,
  }) {
    return PinInputState(
      entered: entered ?? this.entered,
      verifying: verifying ?? this.verifying,
      error: error,
      success: success ?? this.success,
    );
  }
}

/// Manages PIN input, verification, and setup flows.
class PinInputNotifier extends StateNotifier<PinInputState> {
  final PinService _service;
  final int pinLength;

  PinInputNotifier(this._service, {this.pinLength = 6})
      : super(const PinInputState());

  /// Append a digit to the current input.
  void onDigit(int digit) {
    if (state.entered.length >= pinLength) return;
    final next = '${state.entered}$digit';
    state = state.copyWith(entered: next, error: null);

    // Auto-verify when complete.
    if (next.length == pinLength) {
      verify();
    }
  }

  /// Remove the last digit.
  void onBackspace() {
    if (state.entered.isEmpty) return;
    state = state.copyWith(
      entered: state.entered.substring(0, state.entered.length - 1),
      error: null,
    );
  }

  /// Verify the entered PIN against storage.
  Future<void> verify() async {
    state = state.copyWith(verifying: true, error: null);
    final ok = await _service.verify(state.entered);
    if (ok) {
      state = state.copyWith(verifying: false, success: true);
    } else {
      state = state.copyWith(
        verifying: false,
        error: 'Wrong PIN. Try again.',
        entered: '',
      );
    }
  }

  /// Save the current input as the new PIN.
  Future<void> save() async {
    if (state.entered.length < pinLength) return;
    state = state.copyWith(verifying: true, error: null);
    await _service.setPin(state.entered);
    state = state.copyWith(verifying: false, success: true);
  }

  /// Reset state (e.g. after navigating away).
  void reset() {
    state = const PinInputState();
  }
}

/// Provider for the PIN input notifier.
final pinInputProvider =
    StateNotifierProvider.autoDispose<PinInputNotifier, PinInputState>((ref) {
  final service = ref.watch(pinServiceProvider);
  return PinInputNotifier(service);
});
