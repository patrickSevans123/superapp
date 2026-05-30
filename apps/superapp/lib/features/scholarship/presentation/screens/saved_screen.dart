// ─── Saved Scholarships Screen ───────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/scholarship_model.dart';
import '../providers/scholarship_providers.dart';

// ─── Country → Flag Emoji Helper ─────────────────────────────────────────

String _countryFlag(String country) {
  const flags = <String, String>{
    'Jerman': '🇩🇪',
    'Jepang': '🇯🇵',
    'Korea Selatan': '🇰🇷',
    'Tiongkok': '🇨🇳',
    'Amerika Serikat': '🇺🇸',
    'Inggris': '🇬🇧',
    'Australia': '🇦🇺',
    'Singapura': '🇸🇬',
    'Belanda': '🇳🇱',
    'Swiss': '🇨🇭',
    'Indonesia': '🇮🇩',
    'Perancis': '🇫🇷',
    'Kanada': '🇨🇦',
    'Swedia': '🇸🇪',
    'Italia': '🇮🇹',
    'Finlandia': '🇫🇮',
  };
  return flags[country] ?? '🌍';
}

// ─── Saved Screen ────────────────────────────────────────────────────────

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedScholarshipsProvider);

    return savedAsync.when(
      loading: () => GradientBackground(
        child: _buildSkeletonList(),
      ),
      error: (err, _) => GradientBackground(
        child: _buildError(context, err, ref),
      ),
      data: (scholarships) => GradientBackground(
        child: scholarships.isEmpty
            ? _buildEmpty(context)
            : _buildList(context, scholarships, ref),
      ),
    );
  }

  // ─── Skeleton Loading ─────────────────────────────────────────────────

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.elevated,
        highlightColor: AppColors.borderHover,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 10,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: AppColors.hint.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved scholarships yet',
              style: AppTextStyles.title.copyWith(
                color: AppColors.stone,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on a scholarship\nto save it here for quick access',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.hint,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GlassButton(
              label: 'Browse Scholarships',
              icon: Icons.explore,
              onPressed: () => context.go('/scholarship'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, Object error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load saved scholarships',
              style: AppTextStyles.title.copyWith(color: AppColors.stone),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(savedScholarshipsProvider),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Saved List ───────────────────────────────────────────────────────

  Widget _buildList(
    BuildContext context,
    List<ScholarshipModel> scholarships,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(savedScholarshipsProvider);
        await ref.read(savedScholarshipsProvider.future);
      },
      color: AppColors.accent,
      backgroundColor: AppColors.elevated,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: scholarships.length,
        itemBuilder: (context, index) {
          final s = scholarships[index];
          return _buildSavedCard(context, s, ref);
        },
      ),
    );
  }

  // ─── Saved Card (dismissible) ─────────────────────────────────────────

  Widget _buildSavedCard(
    BuildContext context,
    ScholarshipModel s,
    WidgetRef ref,
  ) {
    final deadlineStr = s.deadline != null
        ? 'Due ${_formatDate(s.deadline!)}'
        : null;

    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.bookmark_remove_rounded,
          color: AppColors.error,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        ref.read(savedIdsProvider.notifier).unsave(s.id);
        debugPrint('TODO: unsave scholarship ${s.id} via API');
        return true;
      },
      child: GestureDetector(
        onTap: () => context.go('/scholarship/${s.id}'),
        child: GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      s.title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Provider
                    Text(
                      s.provider,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.stone,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Country + Status badge row
                    Row(
                      children: [
                        // Country
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _countryFlag(s.country),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.country,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.stone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.accent.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            'Saved',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Deadline
                    if (deadlineStr != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 10, color: AppColors.hint),
                          const SizedBox(width: 3),
                          Text(
                            deadlineStr,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              color: AppColors.hint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Funding badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: s.fundingType == 'Fully Funded'
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: s.fundingType == 'Fully Funded'
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  s.fundingType == 'Fully Funded' ? 'Full' : 'Partial',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: s.fundingType == 'Fully Funded'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Date Format Helper ───────────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
