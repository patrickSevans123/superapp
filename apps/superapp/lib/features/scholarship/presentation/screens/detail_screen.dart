// ─── Scholarship Detail Screen ───────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

// ─── Detail Screen ───────────────────────────────────────────────────────

class DetailScreen extends ConsumerWidget {
  final String id;

  const DetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(scholarshipDetailProvider(id));

    return detailAsync.when(
      loading: () => GradientBackground(
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (err, _) => GradientBackground(
        child: _buildError(context, err, ref),
      ),
      data: (scholarship) => _DetailContent(scholarship: scholarship, ref: ref),
    );
  }

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
              'Failed to load details',
              style: AppTextStyles.title.copyWith(
                color: AppColors.stone,
              ),
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
              onPressed: () => ref.invalidate(scholarshipDetailProvider(id)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Content (full page) ──────────────────────────────────────────

class _DetailContent extends ConsumerWidget {
  final ScholarshipModel scholarship;

  const _DetailContent({required this.scholarship, required WidgetRef ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(savedIdsProvider);
    final isSaved = savedIds.contains(scholarship.id);

    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/scholarship'),
        ),
        title: scholarship.title,
        actions: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
            ),
            color: isSaved ? AppColors.accent : AppColors.stone,
            onPressed: () {
              final nowSaved = ref.read(savedIdsProvider.notifier).toggle(scholarship.id);
              debugPrint('TODO: ${nowSaved ? "save" : "unsave"} scholarship ${scholarship.id} via API');
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
              // ── Hero Section ───────────────────────────────────────────
              _buildHero(),

              const SizedBox(height: 16),

              // ── Coverage Details ──────────────────────────────────────
              _buildCoverageCard(),

              const SizedBox(height: 16),

              // ── Description ───────────────────────────────────────────
              _buildDescriptionCard(),

              const SizedBox(height: 16),

              // ── Requirements ──────────────────────────────────────────
              _buildRequirementsCard(),

              const SizedBox(height: 16),

              // ── Level & Fields ─────────────────────────────────────────
              _buildLevelAndFields(),

              const SizedBox(height: 16),

              // ── Deadline Callout ──────────────────────────────────────
              if (scholarship.deadline != null) ...[
                _buildDeadlineCallout(),
                const SizedBox(height: 16),
              ],

              // ── Quick Info / Actions ──────────────────────────────────
              _buildQuickInfo(ref, isSaved),

              const SizedBox(height: 16),

              // ── Tips ──────────────────────────────────────────────────
              if (scholarship.tips.isNotEmpty) ...[
                _buildTipsCard(),
                const SizedBox(height: 16),
              ],

              // Bottom padding
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider
        Text(
          scholarship.provider,
          style: AppTextStyles.body.copyWith(
            color: AppColors.stone,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          scholarship.title,
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
                  _countryFlag(scholarship.country),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  scholarship.country,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Funding badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scholarship.fundingType == 'Fully Funded'
                    ? AppColors.success.withOpacity(0.12)
                    : AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: scholarship.fundingType == 'Fully Funded'
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    scholarship.fundingType == 'Fully Funded'
                        ? Icons.workspace_premium
                        : Icons.monetization_on,
                    size: 14,
                    color: scholarship.fundingType == 'Fully Funded'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    scholarship.fundingType,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scholarship.fundingType == 'Fully Funded'
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Coverage Card ────────────────────────────────────────────────────

  Widget _buildCoverageCard() {
    final c = scholarship.coverageDetail;
    final items = [
      _CoverageItem(
        icon: Icons.school,
        label: 'Tuition',
        value: c.tuition,
        covered: c.tuition.isNotEmpty &&
            c.tuition != 'Not Covered' &&
            c.tuition != 'None',
      ),
      _CoverageItem(
        icon: Icons.account_balance_wallet,
        label: 'Stipend',
        value: c.monthlyStipend,
        covered: c.monthlyStipend.isNotEmpty &&
            c.monthlyStipend != 'Not Covered' &&
            c.monthlyStipend != 'None',
      ),
      _CoverageItem(
        icon: Icons.flight,
        label: 'Travel',
        value: c.travel,
        covered: c.travel.isNotEmpty &&
            c.travel != 'Not Covered' &&
            c.travel != 'None',
      ),
      _CoverageItem(
        icon: Icons.home,
        label: 'Accommodation',
        value: c.accommodation,
        covered: c.accommodation.isNotEmpty &&
            c.accommodation != 'Not Covered' &&
            c.accommodation != 'None',
      ),
      _CoverageItem(
        icon: Icons.health_and_safety,
        label: 'Insurance',
        value: c.insurance,
        covered: c.insurance.isNotEmpty &&
            c.insurance != 'Not Covered' &&
            c.insurance != 'None',
      ),
      _CoverageItem(
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
              Icon(Icons.card_giftcard, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Coverage',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => items[i],
          ),
        ],
      ),
    );
  }

  // ─── Description Card ─────────────────────────────────────────────────

  Widget _buildDescriptionCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: scholarship.description,
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
              code: TextStyle(
                backgroundColor: AppColors.elevated,
                color: AppColors.accent,
                fontSize: 12,
              ),
              codeblockDecoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              blockquoteDecoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
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

  // ─── Requirements Card ────────────────────────────────────────────────

  Widget _buildRequirementsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Requirements',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...scholarship.requirements.map(
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
                      color: AppColors.accent.withOpacity(0.7),
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

  // ─── Level & Fields Chips ────────────────────────────────────────────

  Widget _buildLevelAndFields() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // Level badges
        ...scholarship.level.map(
          (l) => GlassBadge(l, accent: true),
        ),

        // Field of study badges
        ...scholarship.fieldOfStudy.map(
          (f) => GlassBadge(f),
        ),
      ],
    );
  }

  // ─── Deadline Callout ─────────────────────────────────────────────────

  Widget _buildDeadlineCallout() {
    final deadline = scholarship.deadline!;
    final now = DateTime.now();
    final daysLeft = deadline.difference(now).inDays;
    final isUrgent = daysLeft >= 0 && daysLeft <= 30;
    final isPast = daysLeft < 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPast
                  ? AppColors.error.withOpacity(0.12)
                  : isUrgent
                      ? AppColors.warning.withOpacity(0.12)
                      : AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPast
                  ? Icons.block
                  : isUrgent
                      ? Icons.alarm
                      : Icons.event,
              size: 22,
              color: isPast
                  ? AppColors.error
                  : isUrgent
                      ? AppColors.warning
                      : AppColors.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPast
                      ? 'Deadline Passed'
                      : isUrgent
                          ? 'Deadline Approaching!'
                          : 'Application Deadline',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isPast
                        ? AppColors.error
                        : isUrgent
                            ? AppColors.warning
                            : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPast
                      ? 'This scholarship closed ${DateFormat('MMM d, yyyy').format(deadline)}'
                      : 'Due ${DateFormat('EEEE, MMMM d, yyyy').format(deadline)}'
                          '${isUrgent ? ' ($daysLeft days left!)' : ''}',
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
    );
  }

  // ─── Quick Info / Actions ─────────────────────────────────────────────

  Widget _buildQuickInfo(WidgetRef ref, bool isSaved) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 18, color: AppColors.accent),
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
                Icon(Icons.language, size: 16, color: AppColors.hint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scholarship.url,
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
              final uri = Uri.tryParse(scholarship.url);
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
            onPressed: () {
              final nowSaved = ref.read(savedIdsProvider.notifier).toggle(scholarship.id);
              debugPrint('TODO: ${nowSaved ? "save" : "unsave"} scholarship ${scholarship.id} via API');
            },
          ),
        ],
      ),
    );
  }

  // ─── Tips Card ────────────────────────────────────────────────────────

  Widget _buildTipsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Tips',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...scholarship.tips.asMap().entries.map(
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
                        color: AppColors.warning.withOpacity(0.12),
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

// ─── Coverage Item Widget ────────────────────────────────────────────────

class _CoverageItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool covered;

  const _CoverageItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.covered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: covered
              ? AppColors.success.withOpacity(0.2)
              : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: covered ? AppColors.success : AppColors.hint,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.hint,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              color: covered ? AppColors.success : AppColors.stone,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
