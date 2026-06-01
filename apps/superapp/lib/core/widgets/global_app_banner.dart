import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../features/trade/data/models/scraper_health.dart';
import '../../features/trade/presentation/providers/trade_providers.dart';
import '../notifications/in_app_notifications_notifier.dart';

/// Top-of-screen banner host.
///
/// Wrap the body of [MaterialApp.router] (or any navigator) in this
/// widget and the banner will sit above every screen as a [Stack]
/// overlay. Any feature can push a notification by reading
/// [globalInAppNotificationsProvider]:
///
/// ```dart
/// ref.read(globalInAppNotificationsProvider.notifier).push(
///       InAppNotification.create(
///         level: InAppNotificationLevel.success,
///         title: 'Saved',
///         body: 'Item added to your wardrobe.',
///         duration: const Duration(seconds: 3),
///       ),
///     );
/// ```
///
/// The widget also watches [scrapersHealthProvider] and, whenever the
/// set of stale scrapers changes, pushes a single deduplicated warning
/// notification (see [_ScraperHealthWatcher]).
class GlobalAppBanner extends ConsumerStatefulWidget {
  const GlobalAppBanner({super.key, required this.child});

  /// The screen content the banner sits on top of. Typically the
  /// child supplied to [MaterialApp.builder] / [MaterialApp.router.builder].
  final Widget child;

  @override
  ConsumerState<GlobalAppBanner> createState() => _GlobalAppBannerState();
}

class _GlobalAppBannerState extends ConsumerState<GlobalAppBanner> {
  @override
  Widget build(BuildContext context) {
    // Side-effect: side-channel scraper-health warnings into the
    // notification stack. ref.listen does NOT cause a rebuild, it just
    // invokes the callback whenever the watched provider's state changes.
    ref.listen<AsyncValue<ScraperHealth>>(scrapersHealthProvider, (_, next) {
      next.whenData((health) {
        final pending = _ScraperHealthWatcher.handle(health);
        final notifier =
            ref.read(globalInAppNotificationsProvider.notifier);
        for (final n in pending) {
          notifier.push(n);
        }
      });
    });

    final notifications = ref.watch(globalInAppNotificationsProvider);

    return Stack(
      children: [
        widget.child,
        if (notifications.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _BannerStack(notifications: notifications),
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
//  Scraper-health → notification side channel
// ───────────────────────────────────────────────────────────────────────

/// Turns scraper-health updates into dedup'd warning notifications.
///
/// De-dup rule: we only push when the *set of currently-stale source
/// names* changes. As long as the same set is reported on every 60s
/// poll, no new notification is pushed. A new source going stale, or
/// a stale source recovering, both count as a set change.
class _ScraperHealthWatcher {
  /// Set of stale source names that the notifier has already been
  /// notified about. Module-level so it survives widget rebuilds but
  /// is process-local (cleared on hot restart).
  static final Set<String> _seenStale = <String>{};

  /// Stable id used for scraper-stale warnings. The dedup logic in
  /// [InAppNotificationsNotifier.push] also dedupes across rapid
  /// rebuilds of the watcher using this id.
  static const String staleBannerId = '__scraper_stale_warning__';

  /// Pure function over the input [health]. Returns the notifications
  /// to push (often empty). Caller is responsible for actually
  /// pushing them.
  static List<InAppNotification> handle(ScraperHealth health) {
    if (health.allHealthy || health.sources.isEmpty) {
      _seenStale.clear();
      return const [];
    }
    final staleNow = <String>{
      for (final s in health.sources)
        if (s.stale) s.source,
    };
    if (staleNow.isEmpty) {
      _seenStale.clear();
      return const [];
    }

    // Only react when the set of stale sources changes (avoids spam
    // on every 60s poll when the same sources remain stale).
    final newOnes = staleNow.difference(_seenStale);
    _seenStale
      ..clear()
      ..addAll(staleNow);

    if (newOnes.isEmpty) return const [];

    final worst = health.worstOffender;
    final String title;
    final String body;
    if (newOnes.length == 1) {
      final src = _humaniseSource(newOnes.first);
      final label = worst?.ageLabel ?? 'a while';
      title = '$src data is stale';
      body = 'No fresh update in $label. Showing the latest cached data.';
    } else {
      title = '${newOnes.length} scrapers are stale';
      body = 'Showing the latest cached data while sources catch up.';
    }

    return [
      InAppNotification(
        id: staleBannerId, // stable → dedup'd by the notifier
        level: InAppNotificationLevel.warning,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        duration: const Duration(seconds: 6),
        // No onAction here — the banner widget routes the action
        // through its own BuildContext so we can navigate.
        actionLabel: 'View status',
        onAction: null,
      ),
    ];
  }

  static String _humaniseSource(String s) {
    switch (s) {
      case 'bloomberg_english':
        return 'Bloomberg English';
      case 'bloomberg_technoz':
        return 'Bloomberg Technoz';
      case 'reuters':
        return 'Reuters';
      case 'msci':
        return 'MSCI';
      case 'trading_plans':
        return 'Trading plans';
      default:
        return s;
    }
  }
}

// ───────────────────────────────────────────────────────────────────────
//  Stack renderer + per-item enter / exit animation
// ───────────────────────────────────────────────────────────────────────

class _BannerStack extends StatelessWidget {
  const _BannerStack({required this.notifications});

  final List<InAppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Ignore the bottom safe area — the stack sits at the top.
      bottom: false,
      child: Column(
        // Newest banners first (list is already in that order).
        children: [
          for (final n in notifications)
            _AnimatedBannerItem(
              key: ValueKey(n.id),
              notification: n,
            ),
        ],
      ),
    );
  }
}

/// Stateful wrapper that owns the per-item entry/exit animation.
///
/// Entry  : 200 ms ease-out — slide-down (Offset(0, -0.35) → 0,0) + fade
/// Exit   : 200 ms ease-in  — slide-up   (Offset(0, 0)     → 0,-0.35) + fade
///
/// User-triggered exit is local (we reverse the animation, then call
/// the notifier). Auto-dismiss exits via the notifier removing the
/// item; the widget is then unmounted without a per-item exit
/// animation — the surrounding Column handles the layout shrink.
class _AnimatedBannerItem extends ConsumerStatefulWidget {
  const _AnimatedBannerItem({super.key, required this.notification});

  final InAppNotification notification;

  @override
  ConsumerState<_AnimatedBannerItem> createState() =>
      _AnimatedBannerItemState();
}

class _AnimatedBannerItemState extends ConsumerState<_AnimatedBannerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Entry: fade in + slide DOWN (from above the slot into place).
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_exiting) return;
    _exiting = true;
    // Reverse plays the ease-in exit: slide up + fade out.
    await _ctrl.reverse();
    if (!mounted) return;
    ref
        .read(globalInAppNotificationsProvider.notifier)
        .dismiss(widget.notification.id);
  }

  Future<void> _onAction() async {
    // Run the notification's callback first, then dismiss the banner
    // so the user gets clear visual feedback that their tap landed.
    widget.notification.onAction?.call();
    // For the special scraper-stale id, navigate via our own context.
    if (widget.notification.id == _ScraperHealthWatcher.staleBannerId) {
      try {
        GoRouter.of(context).go('/trade/news');
      } catch (_) {
        // GoRouter not available in tests or before MaterialApp is ready.
      }
    }
    await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _BannerCard(
          notification: widget.notification,
          onDismiss: _dismiss,
          onAction: _onAction,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
//  Visual
// ───────────────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.notification,
    required this.onDismiss,
    required this.onAction,
  });

  final InAppNotification notification;
  final Future<void> Function() onDismiss;
  final Future<void> Function() onAction;

  Color get _accent {
    switch (notification.level) {
      case InAppNotificationLevel.info:
        return AppColors.accent;
      case InAppNotificationLevel.warning:
        return AppColors.warning;
      case InAppNotificationLevel.error:
        return AppColors.error;
      case InAppNotificationLevel.success:
        return AppColors.success;
    }
  }

  IconData get _icon {
    switch (notification.level) {
      case InAppNotificationLevel.info:
        return Icons.info_outline_rounded;
      case InAppNotificationLevel.warning:
        return Icons.warning_amber_rounded;
      case InAppNotificationLevel.error:
        return Icons.error_outline_rounded;
      case InAppNotificationLevel.success:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _accent;
    final hasAction =
        notification.actionLabel != null && notification.onAction != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        type: MaterialType.transparency,
        // Tapping the body dismisses the banner — feels like a toast
        // and matches what users expect from in-app notification cards.
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onDismiss(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            decoration: BoxDecoration(
              // Tinted-glass background — solid colour at 12% opacity.
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.40), width: 1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon chip ─────────────────────────────────────────
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),

                // ── Title + body ─────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notification.title,
                        style: AppTextStyles.title.copyWith(
                          fontSize: 14,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.stone,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ── Optional action button ───────────────────────────
                if (hasAction) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => onAction(),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppTextStyles.label.copyWith(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(notification.actionLabel!),
                  ),
                ],

                // ── Dismiss button ───────────────────────────────────
                IconButton(
                  tooltip: 'Dismiss',
                  icon: Icon(Icons.close, size: 18, color: AppColors.hint),
                  onPressed: () => onDismiss(),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
