import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Represents the latest version info from the server.
class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final int fileSize;

  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    this.fileSize = 0,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: json['version'] as String? ?? '0.0.0',
      buildNumber: json['build_number'] as int? ?? 0,
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      forceUpdate: json['force_update'] as bool? ?? false,
      fileSize: json['file_size'] as int? ?? 0,
    );
  }

  /// Check if this version is newer than [currentVersion] / [currentBuildNumber].
  bool isNewerThan(String currentVersion, int currentBuildNumber) {
    // Compare build numbers first (more reliable than semver strings).
    if (buildNumber > currentBuildNumber) return true;
    if (buildNumber < currentBuildNumber) return false;

    // Same build number — compare semver strings.
    final currentParts = currentVersion.split('.');
    final latestParts = version.split('.');

    for (var i = 0; i < latestParts.length; i++) {
      final current = int.tryParse(currentParts.elementAtOrNull(i) ?? '0') ?? 0;
      final latest = int.tryParse(latestParts[i]) ?? 0;
      if (latest > current) return true;
      if (latest < current) return false;
    }
    return false;
  }
}

/// Download progress callback type.
typedef DownloadProgressCallback = void Function(
  double progress,
  int received,
  int total,
);

/// Service that handles checking for app updates, downloading APKs,
/// and triggering installation on Android.
class UpdateService {
  final Dio _dio;

  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  /// Check for an update from the server.
  ///
  /// Returns `null` if no update is available or if the check fails.
  Future<AppVersionInfo?> checkForUpdate({
    required String baseUrl,
    required String currentVersion,
    required int currentBuildNumber,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl/app/version',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final info = AppVersionInfo.fromJson(
          response.data as Map<String, dynamic>,
        );

        if (info.isNewerThan(currentVersion, currentBuildNumber)) {
          return info;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[UpdateService] check failed: $e');
      return null;
    }
  }

  /// Download the APK to the app's cache directory and return the file path.
  ///
  /// Downloads to app-private storage so no storage permissions are needed.
  Future<String?> downloadApk({
    required String downloadUrl,
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'superapp_update_${DateTime.now().millisecondsSinceEpoch}.apk';
      final filePath = '${dir.path}/$fileName';

      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total, received, total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      debugPrint('[UpdateService] APK downloaded to $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[UpdateService] download failed: $e');
      return null;
    }
  }

  /// Open the APK with the system package installer.
  ///
  /// Uses [open_filex] which handles the FileProvider setup required
  /// for Android 7+ (API 24+). The user will see the standard
  /// "Install unknown app" prompt if needed.
  Future<bool> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      debugPrint('[UpdateService] APK install is Android-only');
      return false;
    }

    try {
      final result = await OpenFilex.open(apkPath);
      if (result.type == ResultType.done) {
        debugPrint('[UpdateService] install intent sent');
        return true;
      } else {
        debugPrint('[UpdateService] open failed: ${result.message}');
        return false;
      }
    } catch (e) {
      debugPrint('[UpdateService] install error: $e');
      return false;
    }
  }

  /// Clean up old update APK files from the temp directory.
  Future<void> cleanupOldDownloads() async {
    try {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync();
      for (final file in files) {
        if (file.path.contains('superapp_update_') &&
            file.path.endsWith('.apk')) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] cleanup failed: $e');
    }
  }
}
