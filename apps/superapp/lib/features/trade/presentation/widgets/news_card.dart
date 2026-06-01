import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/models.dart';

/// A tile for displaying a [NewsItem].
///
/// Shows the title, a colour-coded source pill, a relative timestamp
/// (with an amber "Stale" dot for content older than 12h), the API-provided
/// [NewsItem.contentPreview] (with sensible fallbacks), and the URL host in
/// a tiny bottom-right caption. On web/desktop a subtle accent glow is
/// rendered on hover via [MouseRegion].
///
/// Tapping the card invokes the caller-provided [onTap], or — when [onTap]
/// is null and [NewsItem.url] is set — launches the URL externally.
class NewsCard extends StatefulWidget {
  final NewsItem item;
  final VoidCallback? onTap;

  const NewsCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final body = _resolveBody(item);
    final age = _relativeTime(item);
    final stale = _isStale(item);
    final host = _hostOf(item.url);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.18),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : const [],
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          onTap: widget.onTap ??
              (item.url != null ? () => _openUrl(item.url!) : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _SourcePill(source: item.source),
                  const SizedBox(width: 8),
                  if (stale) ...[
                    Tooltip(
                      message: 'Stale',
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    age,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.stone,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (host != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    host,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.hint,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  /// Best-effort body text: API preview → summary → first 180 chars of
  /// [NewsItem.content] (trimmed on a word boundary, ellipsised).
  String _resolveBody(NewsItem item) {
    final preview = item.contentPreview;
    if (preview != null && preview.isNotEmpty) return preview;
    final summary = item.summary;
    if (summary != null && summary.isNotEmpty) return summary;
    final content = item.content;
    if (content == null || content.isEmpty) return '';
    const maxLen = 180;
    if (content.length <= maxLen) return content;
    final cut = content.substring(0, maxLen);
    final sp = cut.lastIndexOf(' ');
    return ((sp > 80 ? cut.substring(0, sp) : cut).trim()) + '…';
  }

  /// Human-friendly relative timestamp. Falls back to [NewsItem.date]
  /// when [NewsItem.processedAt] is null or in the future.
  String _relativeTime(NewsItem item) {
    final ts = item.processedAt;
    if (ts == null) return item.date;
    final diff = DateTime.now().toUtc().difference(ts.toUtc());
    if (diff.isNegative) return item.date;
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _isStale(NewsItem item) {
    final ts = item.processedAt;
    if (ts == null) return false;
    return DateTime.now().toUtc().difference(ts.toUtc()).inHours >= 12;
  }

  String? _hostOf(String? url) {
    if (url == null || url.isEmpty) return null;
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return null;
    return u.host;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Compact pill that colour-codes a [NewsItem.source] value.
///
/// Bloomberg English uses the app accent (violet), Bloomberg Technoz uses
/// the same amber as [AppColors.warning], and Reuters uses a deeper
/// orange-red. Unknown sources fall back to a neutral stone pill.
class _SourcePill extends StatelessWidget {
  final String? source;
  const _SourcePill({this.source});

  static const _reutersOrange = Color(0xFFEA580C);
  static const _technozOrange = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final s = source ?? '';
    final color = _colorFor(s);
    final label = _labelFor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }

  Color _colorFor(String s) {
    switch (s) {
      case 'bloomberg_english':
        return AppColors.accent;
      case 'bloomberg_technoz':
        return _technozOrange;
      case 'reuters':
        return _reutersOrange;
      default:
        return AppColors.stone;
    }
  }

  String _labelFor(String s) {
    switch (s) {
      case 'bloomberg_english':
        return 'BLOOMBERG EN';
      case 'bloomberg_technoz':
        return 'BLOOMBERG TECHNOZ';
      case 'reuters':
        return 'REUTERS';
      default:
        return s.isEmpty ? 'NEWS' : s.toUpperCase();
    }
  }
}
