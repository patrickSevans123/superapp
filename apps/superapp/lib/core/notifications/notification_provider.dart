import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';

/// Provider that exposes the notification stream
final notificationStreamProvider = StreamProvider<AppNotification>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.onNotification;
});

/// Provider for unread notification count
final unreadCountProvider = StateProvider<int>((ref) => 0);
