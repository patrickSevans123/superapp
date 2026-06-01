import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/api/api.dart';
import '../../data/models/models.dart';
import 'fashion_providers.dart';

// ─── Tryon Phase Enum ──────────────────────────────────────────────────────

enum TryonPhase { idle, pickingPerson, uploading, processing, done, error, history }

// ─── Tryon History Item ────────────────────────────────────────────────────

/// Wraps [TryonResult] for UI consumption, matching the cloth-chooser interface.
class TryonHistoryItem {
  final String id;
  final String resultImageUrl;
  final String? personImageUrl;
  final String? garmentName;
  final String? garmentCategory;
  final DateTime createdAt;

  const TryonHistoryItem({
    required this.id,
    required this.resultImageUrl,
    this.personImageUrl,
    this.garmentName,
    this.garmentCategory,
    required this.createdAt,
  });

  factory TryonHistoryItem.fromTryonResult(TryonResult r) {
    return TryonHistoryItem(
      id: r.id,
      resultImageUrl: r.resultImageUrl ?? '',
      personImageUrl: r.personImageUrl,
      garmentName: r.clothingName,
      garmentCategory: r.clothingCategory,
      createdAt: r.createdAt,
    );
  }
}

// ─── Tryon State ───────────────────────────────────────────────────────────

class TryonState {
  const TryonState({
    this.phase = TryonPhase.idle,
    this.garmentItemId,
    this.garmentImageUrl,
    this.personFile,
    this.personImageUrl,
    this.resultImageUrl,
    this.statusMessage,
    this.error,
    this.history = const [],
    this.isLoadingHistory = false,
  });

  final TryonPhase phase;
  final String? garmentItemId;
  final String? garmentImageUrl;
  final File? personFile;
  final String? personImageUrl;
  final String? resultImageUrl;
  final String? statusMessage;
  final String? error;
  final List<TryonHistoryItem> history;
  final bool isLoadingHistory;

  TryonState copyWith({
    TryonPhase? phase,
    String? garmentItemId,
    String? garmentImageUrl,
    File? personFile,
    String? personImageUrl,
    String? resultImageUrl,
    String? statusMessage,
    String? error,
    List<TryonHistoryItem>? history,
    bool? isLoadingHistory,
  }) =>
      TryonState(
        phase: phase ?? this.phase,
        garmentItemId: garmentItemId ?? this.garmentItemId,
        garmentImageUrl: garmentImageUrl ?? this.garmentImageUrl,
        personFile: personFile ?? this.personFile,
        personImageUrl: personImageUrl ?? this.personImageUrl,
        resultImageUrl: resultImageUrl ?? this.resultImageUrl,
        statusMessage: statusMessage ?? this.statusMessage,
        error: error,
        history: history ?? this.history,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      );
}

// ─── Tryon Notifier ────────────────────────────────────────────────────────

class TryonNotifier extends StateNotifier<TryonState> {
  TryonNotifier(this._api, this._dio) : super(const TryonState());

  final FashionApiClient _api;
  final Dio _dio;
  final _picker = ImagePicker();

  void setGarment(String itemId, String imageUrl) {
    state = state.copyWith(
      garmentItemId: itemId,
      garmentImageUrl: imageUrl,
      phase: TryonPhase.idle,
    );
  }

  Future<void> pickPersonPhoto() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return;
    state = state.copyWith(personFile: File(xFile.path));
  }

  Future<void> run() async {
    if (state.garmentImageUrl == null || state.personFile == null) return;

    state = state.copyWith(
        phase: TryonPhase.uploading, statusMessage: 'Uploading person photo...');

    try {
      // Upload person photo via shared auth-aware Dio
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
            state.personFile!.path, filename: 'person.jpg'),
      });
      final uploadResponse = await _dio.post('/upload/photo', data: formData);
      final personUrl = uploadResponse.data['url'] as String;

      state = state.copyWith(
          personImageUrl: personUrl,
          phase: TryonPhase.processing,
          statusMessage: 'Running virtual try-on...');

      // Submit to the Go API backend
      final result = await _api.submitTryon(
        state.garmentImageUrl!,
        personUrl,
      );

      // Extract result URL from response
      final resultUrl = (result['result_image_url'] as String?) ??
          (result['output_url'] as String?) ??
          '';

      if (resultUrl.isEmpty) {
        throw Exception('No result URL in API response: $result');
      }

      state = state.copyWith(
        phase: TryonPhase.done,
        resultImageUrl: resultUrl,
        statusMessage: null,
      );
    } catch (e) {
      state = state.copyWith(phase: TryonPhase.error, error: e.toString());
    }
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    try {
      final items = await _api.getTryonHistory();
      state = state.copyWith(
        history: items.map(TryonHistoryItem.fromTryonResult).toList(),
        isLoadingHistory: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> deleteHistoryItem(String id) async {
    try {
      await _api.deleteTryonItem(id);
      state = state.copyWith(
        history: state.history.where((h) => h.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete: $e');
    }
  }

  void reset() => state = const TryonState();
}

// ─── Providers ─────────────────────────────────────────────────────────────

final tryonNotifierProvider =
    StateNotifierProvider<TryonNotifier, TryonState>((ref) {
  return TryonNotifier(
    ref.read(fashionApiClientProvider),
    ref.read(authDioProvider),
  );
});
