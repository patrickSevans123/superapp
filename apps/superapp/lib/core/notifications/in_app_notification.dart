import 'dart:math';

import 'package:flutter/foundation.dart';

/// Severity tier of a banner. Drives the icon, accent colour and
/// tinted-glass background of [GlobalAppBanner].
enum InAppNotificationLevel {
  /// Neutral / informational — uses [AppColors.accent].
  info,

  /// Degraded but not broken — uses [AppColors.warning] (amber).
  warning,

  /// Failed action / hard error — uses [AppColors.error] (red).
  error,

  /// Positive confirmation — uses [AppColors.success] (emerald).
  success,
}

/// Immutable payload describing a single in-app banner.
///
/// Construct with [InAppNotification.create] when the caller doesn't care
/// about the id (the factory generates a unique one). Use the const
/// constructor when you need a stable id (e.g. for de-duplication).
@immutable
class InAppNotification {
  /// Stable identifier. Two notifications with the same id are treated
  /// as the same notification (de-duplicated on push).
  final String id;

  /// Severity tier — picks the colour and icon.
  final InAppNotificationLevel level;

  /// Single-line headline. Will be ellipsised if it overflows.
  final String title;

  /// Supporting copy. Up to three lines before being truncated.
  final String body;

  /// Wall-clock time the notification was created. Used for sort order
  /// and (optionally) for "5m ago" labels in the future.
  final DateTime createdAt;

  /// If non-null, the banner is auto-dismissed this long after
  /// [createdAt]. If null, the banner is sticky and must be
  /// dismissed by the user.
  final Duration? duration;

  /// Optional CTA label. Rendered as a small text button to the right
  /// of the body. Requires [onAction] to be set.
  final String? actionLabel;

  /// Optional CTA callback. Invoked before the banner is dismissed.
  final VoidCallback? onAction;

  const InAppNotification({
    required this.id,
    required this.level,
    required this.title,
    required this.body,
    required this.createdAt,
    this.duration,
    this.actionLabel,
    this.onAction,
  });

  /// Convenience constructor that auto-generates a unique id.
  ///
  /// Id format: `<microseconds-since-epoch>-<random32>` in base 36.
  /// Collisions are astronomically unlikely in-process.
  factory InAppNotification.create({
    required InAppNotificationLevel level,
    required String title,
    required String body,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final now = DateTime.now();
    final rand = Random();
    final id =
        '${now.microsecondsSinceEpoch.toRadixString(36)}-${rand.nextInt(1 << 32).toRadixString(36)}';
    return InAppNotification(
      id: id,
      level: level,
      title: title,
      body: body,
      createdAt: now,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is InAppNotification && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
