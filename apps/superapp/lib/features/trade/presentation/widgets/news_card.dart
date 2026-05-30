import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/models.dart';

/// A tile for displaying a [NewsItem].
///
/// Shows title, date, source badge, and supports tap to open URL.
/// Wrapped in a [GlassCard] to match the superapp's glass-morphism theme.
class NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback? onTap;

  const NewsCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      onTap: onTap ?? (item.url != null ? () => _openUrl(context) : null),
      child: Row(
        children: [
          Expanded(
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
                    if (item.source != null) ...[
                      GlassBadge(item.source!),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      item.date,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                if (item.summary != null && item.summary!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.summary!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.stone,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (item.url != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.open_in_new,
                size: 16,
                color: AppColors.hint,
              ),
            ),
        ],
      ),
    );
  }

  void _openUrl(BuildContext context) async {
    if (item.url == null) return;
    final uri = Uri.tryParse(item.url!);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
