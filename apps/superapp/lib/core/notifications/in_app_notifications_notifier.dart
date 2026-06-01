import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'in_app_notification.dart';

export 'in_app_notification.dart';

/// In-process stack of currently-visible banners.
///
/// State is the list, **newest first**. The stack is capped at
/// [maxStack] entries — pushing a new one when full evicts the oldest.
/// Banners with a non-null [InAppNotification.duration] are removed
/// automatically after the timer fires; manual [dismiss] / [clear]
/// are always honoured.
class InAppNotificationsNotifier
    extends StateNotifier<List<InAppNotification>> {
  InAppNotificationsNotifier() : super(const []);

  /// Maximum number of banners on screen at once. Older banners are
  /// evicted FIFO when a new push would exceed this.
  static const int maxStack = 3;

  /// Pending auto-dismiss timers keyed by notification id. Cleared
  /// implicitly when the timer fires, or explicitly on manual dismiss.
  final Map<String, Timer> _timers = {};

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  /// Adds a notification to the top of the stack.
  ///
  /// De-duplicates by [InAppNotification.id] — a push with the same id
  /// as an existing notification is ignored (no-op).
  void push(InAppNotification n) {
    // De-dup: ignore pushes that match an id already on screen.
    if (state.any((existing) => existing.id == n.id)) return;

    // Newest first, then cap the stack.
    final next = <InAppNotification>[n, ...state];
    if (next.length > maxStack) {
      final evicted = next.sublist(maxStack);
      next.removeRange(maxStack, next.length);
      for (final old in evicted) {
        _timers.remove(old.id)?.cancel();
      }
    }
    state = next;

    // Schedule auto-dismissal if a duration was supplied.
    final dur = n.duration;
    if (dur != null) {
      _timers[n.id] = Timer(dur, () => dismiss(n.id));
    }
  }

  /// Removes a notification by id. Safe to call with an unknown id
  /// (no-op) — this is what makes both manual taps and the auto-dismiss
  /// timer converge on the same path.
  void dismiss(String id) {
    _timers.remove(id)?.cancel();
    if (state.isEmpty) return;
    if (!state.any((n) => n.id == id)) return;
    state = state.where((n) => n.id != id).toList();
  }

  /// Removes every notification, cancelling all pending timers.
  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    if (state.isEmpty) return;
    state = const [];
  }
}

/// Global provider for the in-app banner stack. Read from any feature
/// to push notifications:
///
/// ```dart
/// ref.read(globalInAppNotificationsProvider.notifier).push(
///   InAppNotification.create(
///     level: InAppNotificationLevel.success,
///     title: 'Saved',
///     body: 'Item added to your wardrobe.',
///     duration: const Duration(seconds: 3),
///   ),
/// );
/// ```
final globalInAppNotificationsProvider = StateNotifierProvider<
    InAppNotificationsNotifier, List<InAppNotification>>((ref) {
  return InAppNotificationsNotifier();
});
