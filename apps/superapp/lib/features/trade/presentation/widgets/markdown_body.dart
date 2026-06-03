import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_ui/shared_ui.dart';

/// Renders a markdown string with the app's dark-theme palette.
///
/// Stays agnostic about where the markdown comes from (daily report
/// body, research report body, etc.) so it can be reused across the
/// new reports screens.
class MarkdownBody extends StatelessWidget {
  final String data;
  final EdgeInsets padding;

  const MarkdownBody({
    super.key,
    required this.data,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          'No content available.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.hint,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final style = MarkdownStyleSheet(
      p: AppTextStyles.body.copyWith(color: AppColors.ink, height: 1.55),
      h1: AppTextStyles.headline.copyWith(
        color: AppColors.ink,
        fontSize: 24,
      ),
      h2: AppTextStyles.headline.copyWith(
        color: AppColors.ink,
        fontSize: 20,
      ),
      h3: AppTextStyles.title.copyWith(
        color: AppColors.ink,
        fontSize: 17,
      ),
      h4: AppTextStyles.title.copyWith(
        color: AppColors.ink,
        fontSize: 15,
      ),
      strong: AppTextStyles.body.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      em: AppTextStyles.body.copyWith(
        color: AppColors.stone,
        fontStyle: FontStyle.italic,
      ),
      a: AppTextStyles.body.copyWith(
        color: AppColors.accent,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.accent,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: AppColors.accent,
        backgroundColor: AppColors.elevated,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      listBullet: AppTextStyles.body.copyWith(color: AppColors.ink),
      tableHead: AppTextStyles.body.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      tableBody: AppTextStyles.body.copyWith(color: AppColors.stone),
      tableBorder: TableBorder.all(color: AppColors.border),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );

    return Markdown(
      data: data,
      padding: padding,
      selectable: true,
      styleSheet: style,
      onTapLink: (text, href, title) {
        // Keep it simple: link taps are not auto-launched here.
        // Screens that need external link handling should wrap this
        // widget or use url_launcher directly.
      },
    );
  }
}
