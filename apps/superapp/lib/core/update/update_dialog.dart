import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import 'update_provider.dart';

/// Shows the in-app update dialog.
///
/// Call from anywhere with a [BuildContext]:
/// ```dart
/// showUpdateDialog(context);
/// ```
///
/// The dialog handles the full flow: checking → showing release notes →
/// download progress → install prompt. On force-update, the user cannot
/// dismiss the dialog.
void showUpdateDialog(BuildContext context, {bool forceUpdate = false}) {
  showDialog(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (_) => _UpdateDialog(forceUpdate: forceUpdate),
  );
}

class _UpdateDialog extends ConsumerStatefulWidget {
  final bool forceUpdate;
  const _UpdateDialog({this.forceUpdate = false});

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  @override
  void initState() {
    super.initState();
    // Trigger the check when the dialog opens.
    Future.microtask(() {
      ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);

    // Auto-dismiss if up-to-date (unless forced).
    if (state.status == UpdateStatus.upToDate && !widget.forceUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    return PopScope(
      canPop: !widget.forceUpdate || state.status == UpdateStatus.upToDate,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildTitle(state),
        content: _buildContent(state),
        actions: _buildActions(state),
      ),
    );
  }

  Widget _buildTitle(UpdateState state) {
    final String text;
    switch (state.status) {
      case UpdateStatus.checking:
        text = 'Checking for updates...';
      case UpdateStatus.available:
        text = 'Update Available';
      case UpdateStatus.downloading:
        text = 'Downloading...';
      case UpdateStatus.ready:
        text = 'Update Ready';
      case UpdateStatus.error:
        text = 'Update Failed';
      case UpdateStatus.upToDate:
        text = 'You\'re up to date';
      case UpdateStatus.idle:
        text = 'App Update';
    }

    return Row(
      children: [
        Icon(
          state.status == UpdateStatus.upToDate
              ? Icons.check_circle_outline
              : Icons.system_update_rounded,
          color: state.status == UpdateStatus.upToDate
              ? AppColors.success
              : AppColors.accent,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.title.copyWith(
              fontSize: 18,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.checking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );

      case UpdateStatus.available:
        final info = state.latestVersion;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${info?.version ?? "unknown"}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.stone,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            if (info?.releaseNotes.isNotEmpty == true) ...[
              Text(
                'What\'s new:',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  info!.releaseNotes,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.stone,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (info?.forceUpdate == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This update is required.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

      case UpdateStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.downloadProgress,
              backgroundColor: AppColors.stone.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
            const SizedBox(height: 12),
            Text(
              '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
              style: AppTextStyles.body.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case UpdateStatus.ready:
        return Text(
          'The update has been downloaded and is ready to install.',
          style: AppTextStyles.body.copyWith(color: AppColors.stone),
        );

      case UpdateStatus.error:
        return Text(
          state.errorMessage ?? 'An error occurred.',
          style: AppTextStyles.body.copyWith(color: AppColors.error),
        );

      case UpdateStatus.upToDate:
        return Text(
          'You are running the latest version.',
          style: AppTextStyles.body.copyWith(color: AppColors.stone),
        );

      case UpdateStatus.idle:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _buildActions(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.available:
        return [
          if (!widget.forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Later',
                style: AppTextStyles.label.copyWith(color: AppColors.stone),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              ref.read(updateProvider.notifier).downloadUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ];

      case UpdateStatus.downloading:
        return [
          if (!widget.forceUpdate)
            TextButton(
              onPressed: null,
              child: Text(
                'Downloading...',
                style: AppTextStyles.label.copyWith(color: AppColors.stone),
              ),
            ),
        ];

      case UpdateStatus.ready:
        return [
          ElevatedButton(
            onPressed: () async {
              final success =
                  await ref.read(updateProvider.notifier).installUpdate();
              if (success && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Install Now'),
          ),
        ];

      case UpdateStatus.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (!widget.forceUpdate)
            ElevatedButton(
              onPressed: () {
                ref.read(updateProvider.notifier).reset();
                ref.read(updateProvider.notifier).checkForUpdate();
              },
              child: const Text('Retry'),
            ),
        ];

      case UpdateStatus.upToDate:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ];

      case UpdateStatus.checking:
      case UpdateStatus.idle:
        return [];
    }
  }
}
