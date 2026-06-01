// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clothing_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClothingItemModelImpl _$$ClothingItemModelImplFromJson(
        Map<String, dynamic> json) =>
    _$ClothingItemModelImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      seasonTags: (json['season_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      originalImageUrl: json['original_image_url'] as String?,
      processedImageUrl: json['processed_image_url'] as String?,
      dominantColors: (json['dominant_colors'] as List<dynamic>?)
              ?.map((e) => DominantColor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      brand: json['brand'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      timesWorn: (json['times_worn'] as num?)?.toInt() ?? 0,
      lastWornAt: json['last_worn_at'] == null
          ? null
          : DateTime.parse(json['last_worn_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$ClothingItemModelImplToJson(
        _$ClothingItemModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'name': instance.name,
      'category': instance.category,
      'season_tags': instance.seasonTags,
      'original_image_url': instance.originalImageUrl,
      'processed_image_url': instance.processedImageUrl,
      'dominant_colors': instance.dominantColors,
      'brand': instance.brand,
      'cost': instance.cost,
      'times_worn': instance.timesWorn,
      'last_worn_at': instance.lastWornAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
