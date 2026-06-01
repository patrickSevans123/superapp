// â”€â”€â”€ Scholarship Detail Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/scholarship_model.dart';
import '../providers/scholarship_providers.dart';
import '../shared/scholarship_helpers.dart';

// â”€â”€â”€ Application Status Options â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _statusOptions = [
  'Interested',
  'Applied',
  'Interview',
  'Accepted',
  'Rejected',
];

// â”€â”€â”€ Detail Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DetailScreen extends ConsumerStatefulWidget {
  final String id;

  const DetailScreen({super.key, required this.id});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  String? _applicationStatus;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(scholarshipDetailProvider(widget.id));

    return detailAsync.when(
      loading: () => const GradientBackground(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (err, _) => GradientBackground(
        child: _buildError(context, err),
      ),
      data: (scholarship) => _buildScaffold(scholarship),
    );
  }

  Widget _buildScaffold(ScholarshipModel s) {
    final savedIds = ref.watch(savedIdsProvider);
    final isSaved = savedIds.contains(s.id);

    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.scholarship),
        ),
        title: s.title,
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Copy link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: s.url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
          ),
          // Save toggle button
          IconButton(
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            color: isSaved ? AppColors.accent : AppColors.stone,
            onPressed: () async {
              await ref.read(savedIdsProvider.notifier).toggle(s.id);
            },
          ),
        ],
      ),
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // â”€â”€ Hero Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildHero(s),

              const SizedBox(height: 16),

              // â”€â”€ Coverage Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildCoverageCard(s),

              const SizedBox(height: 16),

              // â”€â”€ Description â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildDescriptionCard(s),

              const SizedBox(height: 16),

              // â”€â”€ Requirements â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildRequirementsCard(s),

              const SizedBox(height: 16),

              // â”€â”€ Level & Fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildLevelAndFields(s),

              const SizedBox(height: 16),

              // â”€â”€ Deadline Callout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (s.deadline != null) ...[
                _buildDeadlineCallout(s),
                const SizedBox(height: 16),
              ],

              // â”€â”€ Application Status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildStatusTracking(),

              const SizedBox(height: 16),

              // â”€â”€ Quick Info / Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildQuickInfo(s, ref, isSaved),

              const SizedBox(height: 16),

              // â”€â”€ Tips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (s.tips.isNotEmpty) ...[
                _buildTipsCard(s),
                const SizedBox(height: 16),
              ],

              // â”€â”€ Related Scholarships â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildRelatedScholarships(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              'Failed to load details',
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
              onPressed: () =>
                  ref.invalidate(scholarshipDetailProvider(widget.id)),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Hero Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHero(ScholarshipModel s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider
        Text(
          s.provider,
          style: AppTextStyles.body.copyWith(
            color: AppColors.stone,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          s.title,
          style: AppTextStyles.headline.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 10),

        // Country + Funding badge row
        Row(
          children: [
            // Country
            Row(
              children: [
                Text(
                  countryFlag(s.country),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  s.country,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Funding badge (with icon)
            ScholarshipFundingBadge(
              fundingType: s.fundingType,
              style: FundingBadgeStyle.withIcon,
            ),
          ],
        ),
      ],
    );
  }

  // â”€â”€â”€ Coverage Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildCoverageCard(ScholarshipModel s) {
    final c = s.coverageDetail;
    final items = <Widget>[
      CoverageItemWidget(
        icon: Icons.school,
        label: 'Tuition',
        value: c.tuition,
        covered: c.tuition.isNotEmpty &&
            c.tuition != 'Not Covered' &&
            c.tuition != 'None',
      ),
      CoverageItemWidget(
        icon: Icons.account_balance_wallet,
        label: 'Stipend',
        value: c.monthlyStipend,
        covered: c.monthlyStipend.isNotEmpty &&
            c.monthlyStipend != 'Not Covered' &&
            c.monthlyStipend != 'None',
      ),
      CoverageItemWidget(
        icon: Icons.flight,
        label: 'Travel',
        value: c.travel,
        covered: c.travel.isNotEmpty &&
            c.travel != 'Not Covered' &&
            c.travel != 'None',
      ),
      CoverageItemWidget(
        icon: Icons.home,
        label: 'Accommodation',
        value: c.accommodation,
        covered: c.accommodation.isNotEmpty &&
            c.accommodation != 'Not Covered' &&
            c.accommodation != 'None',
      ),
      CoverageItemWidget(
        icon: Icons.health_and_safety,
        label: 'Insurance',
        value: c.insurance,
        covered: c.insurance.isNotEmpty &&
            c.insurance != 'Not Covered' &&
            c.insurance != 'None',
      ),
      CoverageItemWidget(
        icon: Icons.language,
        label: 'Language',
        value: c.languageCourse,
        covered: c.languageCourse.isNotEmpty &&
            c.languageCourse != 'Not Covered' &&
            c.languageCourse != 'None',
      ),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Coverage',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Responsive grid: 2 cols on narrow (<360), 3 on wider
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 360 ? 2 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => items[i],
              );
            },
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Description Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDescriptionCard(ScholarshipModel s) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: s.description,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: AppTextStyles.body.copyWith(
                color: AppColors.stone,
                fontSize: 13,
                height: 1.6,
              ),
              h3: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.ink,
                height: 1.8,
              ),
              h4: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.ink,
                height: 1.8,
              ),
              listBullet: AppTextStyles.body.copyWith(
                color: AppColors.accent,
                fontSize: 13,
              ),
              code: const TextStyle(
                backgroundColor: AppColors.elevated,
                color: AppColors.accent,
                fontSize: 12,
              ),
              codeblockDecoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              blockquoteDecoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
                border: const Border(
                  left: BorderSide(color: AppColors.accent, width: 3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Requirements Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildRequirementsCard(ScholarshipModel s) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Requirements',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...s.requirements.map(
            (req) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.accent.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      req,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.stone,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Level & Fields Chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildLevelAndFields(ScholarshipModel s) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...s.level.map((l) => GlassBadge(l, accent: true)),
        ...s.fieldOfStudy.map((f) => GlassBadge(f)),
      ],
    );
  }

  // â”€â”€â”€ Deadline Callout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDeadlineCallout(ScholarshipModel s) {
    final info = s.deadline!.deadlineInfo;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  info.icon,
                  size: 22,
                  color: info.color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: info.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.isPast
                          ? 'This scholarship closed ${formatDate(s.deadline!)}'
                          : info.isToday
                              ? 'Deadline is today!'
                              : 'Due ${formatDate(s.deadline!)}'
                                  '${info.isUrgent ? ' (${info.daysLeft} days left!)' : ''}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.stone,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Set Reminder button (only for future deadlines)
          if (!info.isPast) ...[
            const SizedBox(height: 12),
            GlassButton(
              label: 'Set Reminder',
              icon: Icons.notifications_outlined,
              variant: GlassButtonVariant.secondary,
              small: true,
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: s.deadline!.isBefore(DateTime.now())
                      ? DateTime.now().add(const Duration(days: 1))
                      : s.deadline!,
                  firstDate: DateTime.now(),
                  lastDate: s.deadline!.isBefore(DateTime.now())
                      ? DateTime.now().add(const Duration(days: 365))
                      : s.deadline!,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppColors.accent,
                          surface: AppColors.elevated,
                          onSurface: AppColors.ink,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Reminder set for ${formatDate(picked)}',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // â”€â”€â”€ Application Status Tracking â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatusTracking() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Application Status',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _statusOptions.map((status) {
              final isSelected = _applicationStatus == status;
              final isRejected = status == 'Rejected';
              final isAccepted = status == 'Accepted';
              Color chipColor;
              if (isSelected) {
                if (isRejected) {
                  chipColor = AppColors.error;
                } else if (isAccepted) {
                  chipColor = AppColors.success;
                } else {
                  chipColor = AppColors.accent;
                }
              } else {
                chipColor = AppColors.accent;
              }

              return ChoiceChip(
                label: Text(
                  status,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.ink : AppColors.stone,
                  ),
                ),
                selected: isSelected,
                selectedColor: chipColor.withValues(alpha: 0.25),
                backgroundColor: AppColors.elevated,
                side: BorderSide(
                  color: isSelected
                      ? chipColor.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  setState(() {
                    _applicationStatus =
                        isSelected ? null : status;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Quick Info / Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildQuickInfo(
      ScholarshipModel s, WidgetRef ref, bool isSaved) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Quick Info',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // URL info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.language, size: 16, color: AppColors.hint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.url,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.hint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Visit Website button
          GlassButton(
            label: 'Visit Website',
            icon: Icons.open_in_new,
            onPressed: () async {
              final uri = Uri.tryParse(s.url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(height: 10),

          // Save button
          GlassButton(
            label: isSaved ? 'Unsave Scholarship' : 'Save Scholarship',
            icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
            variant: GlassButtonVariant.secondary,
            onPressed: () async {
              await ref.read(savedIdsProvider.notifier).toggle(s.id);
            },
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Related Scholarships â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildRelatedScholarships() {
    final relatedAsync = ref.watch(relatedScholarshipsProvider(widget.id));

    return relatedAsync.when(
      loading: () => _buildRelatedShimmer(),
      error: (err, _) => const SizedBox.shrink(),
      data: (scholarships) {
        if (scholarships.isEmpty) return const SizedBox.shrink();
        return _buildRelatedList(scholarships);
      },
    );
  }

  Widget _buildRelatedShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              'Related Scholarships',
              style: AppTextStyles.title.copyWith(fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(right: 4),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => _buildRelatedShimmerCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 8,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Container(
              height: 10,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedList(List<ScholarshipModel> scholarships) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              'Related Scholarships',
              style: AppTextStyles.title.copyWith(fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 4),
            itemCount: scholarships.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _buildRelatedCard(scholarships[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedCard(ScholarshipModel s) {
    return GlassCard(
      radius: 12,
      onTap: () => context.go(AppRoutes.scholarshipDetailFor(s.id)),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              s.title,
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Country + flag
            Row(
              children: [
                Text(countryFlag(s.country),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.country,
                    style: AppTextStyles.caption.copyWith(fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Funding badge
            ScholarshipFundingBadge(
              fundingType: s.fundingType,
              style: FundingBadgeStyle.compact,
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Tips Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTipsCard(ScholarshipModel s) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Tips',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...s.tips.asMap().entries.map(
            (entry) {
              final index = entry.key + 1;
              final tip = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$index',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.stone,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
