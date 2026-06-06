import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/network_providers.dart';
import 'update_service.dart';

/// Current app version info, loaded once at startup.
final appVersionProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

/// Singleton [UpdateService] instance.
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(dio: ref.watch(authDioProvider));
});

/// State for the update check flow.
enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  ready,
  error,
  upToDate,
}

/// Holds the full state of an in-progress or completed update check.
class UpdateState {
  final UpdateStatus status;
  final AppVersionInfo? latestVersion;
  final double downloadProgress;
  final String? downloadedPath;
  final String? errorMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.latestVersion,
    this.downloadProgress = 0,
    this.downloadedPath,
    this.errorMessage,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    AppVersionInfo? latestVersion,
    double? downloadProgress,
    String? downloadedPath,
    String? errorMessage,
  }) {
    return UpdateState(
      status: status ?? this.status,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedPath: downloadedPath ?? this.downloadedPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier that manages the update check → download → install flow.
class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _service;

  UpdateNotifier(this._service) : super(const UpdateState());

  /// Check for an update against the backend.
  Future<void> checkForUpdate() async {
    state = state.copyWith(status: UpdateStatus.checking);

    // Configured at build time — same as API_BASE_URL but without /api/v1
    const String baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080/api/v1',
    );

    final packageInfo = await PackageInfo.fromPlatform();
    final info = await _service.checkForUpdate(
      baseUrl: baseUrl,
      currentVersion: packageInfo.version,
      currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
    );

    if (info != null) {
      state = state.copyWith(
        status: UpdateStatus.available,
        latestVersion: info,
      );
    } else {
      state = state.copyWith(status: UpdateStatus.upToDate);
    }
  }

  /// Download the latest APK.
  Future<void> downloadUpdate() async {
    final url = state.latestVersion?.downloadUrl;
    if (url == null || url.isEmpty) return;

    state = state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0);

    final path = await _service.downloadApk(
      downloadUrl: url,
      onProgress: (progress, _, __) {
        state = state.copyWith(downloadProgress: progress);
      },
    );

    if (path != null) {
      state = state.copyWith(
        status: UpdateStatus.ready,
        downloadedPath: path,
      );
    } else {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Download failed. Please try again.',
      );
    }
  }

  /// Open the downloaded APK with the system installer.
  Future<bool> installUpdate() async {
    final path = state.downloadedPath;
    if (path == null) return false;
    return _service.installApk(path);
  }

  /// Reset to idle state.
  void reset() {
    state = const UpdateState();
  }
}

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier(ref.watch(updateServiceProvider));
});
