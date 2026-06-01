// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'dominant_color.dart';

part 'clothing_item_model.freezed.dart';
part 'clothing_item_model.g.dart';

@freezed
class ClothingItemModel with _$ClothingItemModel {
  // Private constructor enables custom getters (costPerWear).
  // ignore: unused_element
  const ClothingItemModel._();

  const factory ClothingItemModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String name,
    required String category,
    @JsonKey(name: 'season_tags') @Default([]) List<String> seasonTags,
    @JsonKey(name: 'original_image_url') String? originalImageUrl,
    @JsonKey(name: 'processed_image_url') String? processedImageUrl,
    @JsonKey(name: 'dominant_colors')
    @Default([])
    List<DominantColor> dominantColors,
    String? brand,
    double? cost,
    @JsonKey(name: 'times_worn') @Default(0) int timesWorn,
    @JsonKey(name: 'last_worn_at') DateTime? lastWornAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ClothingItemModel;

  factory ClothingItemModel.fromJson(Map<String, dynamic> json) =>
      _$ClothingItemModelFromJson(json);

  /// Computed: cost per wear based on [timesWorn] and [cost].
  double? get costPerWear =>
      timesWorn > 0 && cost != null ? cost! / timesWorn : null;
}
