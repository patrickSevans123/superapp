// â”€â”€â”€ Saved Scholarships Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/scholarship_model.dart';
import '../providers/scholarship_providers.dart';
import '../shared/scholarship_helpers.dart';

// â”€â”€â”€ Status Cycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _statusCycle = [
  'Interested',
  'Applied',
  'Interview',
  'Accepted',
];

// â”€â”€â”€ Saved Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  /// Maps scholarship ID â†’ application status.
  /// Local state; status is persisted only for the session.
  final Map<String, String> _statusMap = {};

  String? _nextStatus(String? current) {
    if (current == null) return _statusCycle.first;
    final idx = _statusCycle.indexOf(current);
    if (idx < 0 || idx >= _statusCycle.length - 1) return null;
    return _statusCycle[idx + 1];
  }

  void _cycleStatus(String id) {
    setState(() {
      final next = _nextStatus(_statusMap[id]);
      if (next == null) {
        _statusMap.remove(id);
      } else {
        _statusMap[id] = next;
      }
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Interested':
        return AppColors.accent;
      case 'Applied':
        return AppColors.warning;
      case 'Interview':
        return AppColors.accentDim;
      case 'Accepted':
        return AppColors.success;
      default:
        return AppColors.hint;
    }
  }

  // â”€â”€â”€ Sort by deadline helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<ScholarshipModel> _sortByDeadline(List<ScholarshipModel> list) {
    final sorted = List<ScholarshipModel>.from(list);
    sorted.sort((a, b) {
      if (a.deadline == null && b.deadline == null) return 0;
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final savedAsync = ref.watch(savedScholarshipsProvider);

    return savedAsync.when(
      loading: () => GradientBackground(
        child: _buildSkeletonList(),
      ),
      error: (err, _) => GradientBackground(
        child: _buildError(context, err),
      ),
      data: (scholarships) => GradientBackground(
        child: scholarships.isEmpty
            ? _buildEmpty(context)
            : _buildList(context, _sortByDeadline(scholarships)),
      ),
    );
  }

  // â”€â”€â”€ Skeleton Loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€â”€ Empty State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              color: AppColors.hint.withValues(alpha: 0.5),
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
              onPressed: () => context.go(AppRoutes.scholarship),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withValues(alpha: 0.7),
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
                color: AppColors.error.withValues(alpha: 0.7),
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

  // â”€â”€â”€ Saved List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildList(
    BuildContext context,
    List<ScholarshipModel> scholarships,
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
          return _buildSavedCard(context, s);
        },
      ),
    );
  }

  // â”€â”€â”€ Saved Card (dismissible + status chip) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSavedCard(BuildContext context, ScholarshipModel s) {
    final hasDeadline = s.deadline != null;
    final deadlineInfo = hasDeadline ? s.deadline!.deadlineInfo : null;
    final status = _statusMap[s.id];

    return Dismissible(
      key: ValueKey('saved_${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.bookmark_remove_rounded,
          color: AppColors.error,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        await ref.read(savedIdsProvider.notifier).unsave(s.id);

        if (!context.mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${s.title} removed',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                ref.read(savedIdsProvider.notifier).save(s.id);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        return true;
      },
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.scholarshipDetailFor(s.id)),
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

                    // Country + Status chip row
                    Row(
                      children: [
                        // Country
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              countryFlag(s.country),
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

                        // Status chip (tappable to cycle)
                        GestureDetector(
                          onTap: () => _cycleStatus(s.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: status != null
                                  ? _statusColor(status).withValues(alpha: 0.12)
                                  : AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: status != null
                                    ? _statusColor(status).withValues(alpha: 0.3)
                                    : AppColors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              status ?? 'Saved',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: status != null
                                    ? _statusColor(status)
                                    : AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Deadline
                    if (hasDeadline) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 10,
                              color: deadlineInfo!.isUrgent
                                  ? AppColors.warning
                                  : AppColors.hint),
                          const SizedBox(width: 3),
                          Text(
                            deadlineInfo.isUrgent
                                ? '${deadlineInfo.daysLeft} days left'
                                : 'Due ${formatDate(s.deadline!)}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              color: deadlineInfo.isUrgent
                                  ? AppColors.warning
                                  : AppColors.hint,
                              fontWeight: deadlineInfo.isUrgent
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Funding badge
              ScholarshipFundingBadge(fundingType: s.fundingType),
            ],
          ),
        ),
      ),
    );
  }
}
