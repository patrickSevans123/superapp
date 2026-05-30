// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clothing_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ClothingItemModel _$ClothingItemModelFromJson(Map<String, dynamic> json) {
  return _ClothingItemModel.fromJson(json);
}

/// @nodoc
mixin _$ClothingItemModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  @JsonKey(name: 'season_tags')
  List<String> get seasonTags => throw _privateConstructorUsedError;
  @JsonKey(name: 'original_image_url')
  String? get originalImageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'processed_image_url')
  String? get processedImageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'dominant_colors')
  List<DominantColor> get dominantColors => throw _privateConstructorUsedError;
  String? get brand => throw _privateConstructorUsedError;
  double? get cost => throw _privateConstructorUsedError;
  @JsonKey(name: 'times_worn')
  int get timesWorn => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_worn_at')
  DateTime? get lastWornAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Computed: cost per wear based on [timesWorn] and [cost].
  double? get costPerWear => throw _privateConstructorUsedError;

  /// Serializes this ClothingItemModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ClothingItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClothingItemModelCopyWith<ClothingItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClothingItemModelCopyWith<$Res> {
  factory $ClothingItemModelCopyWith(
          ClothingItemModel value, $Res Function(ClothingItemModel) then) =
      _$ClothingItemModelCopyWithImpl<$Res, ClothingItemModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      String name,
      String category,
      @JsonKey(name: 'season_tags') List<String> seasonTags,
      @JsonKey(name: 'original_image_url') String? originalImageUrl,
      @JsonKey(name: 'processed_image_url') String? processedImageUrl,
      @JsonKey(name: 'dominant_colors') List<DominantColor> dominantColors,
      String? brand,
      double? cost,
      @JsonKey(name: 'times_worn') int timesWorn,
      @JsonKey(name: 'last_worn_at') DateTime? lastWornAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$ClothingItemModelCopyWithImpl<$Res, $Val extends ClothingItemModel>
    implements $ClothingItemModelCopyWith<$Res> {
  _$ClothingItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ClothingItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? name = null,
    Object? category = null,
    Object? seasonTags = null,
    Object? originalImageUrl = freezed,
    Object? processedImageUrl = freezed,
    Object? dominantColors = null,
    Object? brand = freezed,
    Object? cost = freezed,
    Object? timesWorn = null,
    Object? lastWornAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      seasonTags: null == seasonTags
          ? _value.seasonTags
          : seasonTags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      originalImageUrl: freezed == originalImageUrl
          ? _value.originalImageUrl
          : originalImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      processedImageUrl: freezed == processedImageUrl
          ? _value.processedImageUrl
          : processedImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      dominantColors: null == dominantColors
          ? _value.dominantColors
          : dominantColors // ignore: cast_nullable_to_non_nullable
              as List<DominantColor>,
      brand: freezed == brand
          ? _value.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      cost: freezed == cost
          ? _value.cost
          : cost // ignore: cast_nullable_to_non_nullable
              as double?,
      timesWorn: null == timesWorn
          ? _value.timesWorn
          : timesWorn // ignore: cast_nullable_to_non_nullable
              as int,
      lastWornAt: freezed == lastWornAt
          ? _value.lastWornAt
          : lastWornAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ClothingItemModelImplCopyWith<$Res>
    implements $ClothingItemModelCopyWith<$Res> {
  factory _$$ClothingItemModelImplCopyWith(_$ClothingItemModelImpl value,
          $Res Function(_$ClothingItemModelImpl) then) =
      __$$ClothingItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      String name,
      String category,
      @JsonKey(name: 'season_tags') List<String> seasonTags,
      @JsonKey(name: 'original_image_url') String? originalImageUrl,
      @JsonKey(name: 'processed_image_url') String? processedImageUrl,
      @JsonKey(name: 'dominant_colors') List<DominantColor> dominantColors,
      String? brand,
      double? cost,
      @JsonKey(name: 'times_worn') int timesWorn,
      @JsonKey(name: 'last_worn_at') DateTime? lastWornAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$$ClothingItemModelImplCopyWithImpl<$Res>
    extends _$ClothingItemModelCopyWithImpl<$Res, _$ClothingItemModelImpl>
    implements _$$ClothingItemModelImplCopyWith<$Res> {
  __$$ClothingItemModelImplCopyWithImpl(_$ClothingItemModelImpl _value,
      $Res Function(_$ClothingItemModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of ClothingItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? name = null,
    Object? category = null,
    Object? seasonTags = null,
    Object? originalImageUrl = freezed,
    Object? processedImageUrl = freezed,
    Object? dominantColors = null,
    Object? brand = freezed,
    Object? cost = freezed,
    Object? timesWorn = null,
    Object? lastWornAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ClothingItemModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      seasonTags: null == seasonTags
          ? _value._seasonTags
          : seasonTags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      originalImageUrl: freezed == originalImageUrl
          ? _value.originalImageUrl
          : originalImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      processedImageUrl: freezed == processedImageUrl
          ? _value.processedImageUrl
          : processedImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      dominantColors: null == dominantColors
          ? _value._dominantColors
          : dominantColors // ignore: cast_nullable_to_non_nullable
              as List<DominantColor>,
      brand: freezed == brand
          ? _value.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      cost: freezed == cost
          ? _value.cost
          : cost // ignore: cast_nullable_to_non_nullable
              as double?,
      timesWorn: null == timesWorn
          ? _value.timesWorn
          : timesWorn // ignore: cast_nullable_to_non_nullable
              as int,
      lastWornAt: freezed == lastWornAt
          ? _value.lastWornAt
          : lastWornAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ClothingItemModelImpl implements _ClothingItemModel {
  const _$ClothingItemModelImpl(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      required this.name,
      required this.category,
      @JsonKey(name: 'season_tags') final List<String> seasonTags = const [],
      @JsonKey(name: 'original_image_url') this.originalImageUrl,
      @JsonKey(name: 'processed_image_url') this.processedImageUrl,
      @JsonKey(name: 'dominant_colors')
      final List<DominantColor> dominantColors = const [],
      this.brand,
      this.cost,
      @JsonKey(name: 'times_worn') this.timesWorn = 0,
      @JsonKey(name: 'last_worn_at') this.lastWornAt,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : _seasonTags = seasonTags,
        _dominantColors = dominantColors;

  factory _$ClothingItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClothingItemModelImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String name;
  @override
  final String category;
  final List<String> _seasonTags;
  @override
  @JsonKey(name: 'season_tags')
  List<String> get seasonTags {
    if (_seasonTags is EqualUnmodifiableListView) return _seasonTags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_seasonTags);
  }

  @override
  @JsonKey(name: 'original_image_url')
  final String? originalImageUrl;
  @override
  @JsonKey(name: 'processed_image_url')
  final String? processedImageUrl;
  final List<DominantColor> _dominantColors;
  @override
  @JsonKey(name: 'dominant_colors')
  List<DominantColor> get dominantColors {
    if (_dominantColors is EqualUnmodifiableListView) return _dominantColors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dominantColors);
  }

  @override
  final String? brand;
  @override
  final double? cost;
  @override
  @JsonKey(name: 'times_worn')
  final int timesWorn;
  @override
  @JsonKey(name: 'last_worn_at')
  final DateTime? lastWornAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  double? get costPerWear =>
      timesWorn > 0 && cost != null ? cost! / timesWorn : null;

  @override
  String toString() {
    return 'ClothingItemModel(id: $id, userId: $userId, name: $name, category: $category, seasonTags: $seasonTags, originalImageUrl: $originalImageUrl, processedImageUrl: $processedImageUrl, dominantColors: $dominantColors, brand: $brand, cost: $cost, timesWorn: $timesWorn, lastWornAt: $lastWornAt, createdAt: $createdAt, updatedAt: $updatedAt, costPerWear: $costPerWear)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClothingItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality()
                .equals(other._seasonTags, _seasonTags) &&
            (identical(other.originalImageUrl, originalImageUrl) ||
                other.originalImageUrl == originalImageUrl) &&
            (identical(other.processedImageUrl, processedImageUrl) ||
                other.processedImageUrl == processedImageUrl) &&
            const DeepCollectionEquality()
                .equals(other._dominantColors, _dominantColors) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.cost, cost) || other.cost == cost) &&
            (identical(other.timesWorn, timesWorn) ||
                other.timesWorn == timesWorn) &&
            (identical(other.lastWornAt, lastWornAt) ||
                other.lastWornAt == lastWornAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        userId,
        name,
        category,
        const DeepCollectionEquality().hash(_seasonTags),
        originalImageUrl,
        processedImageUrl,
        const DeepCollectionEquality().hash(_dominantColors),
        brand,
        cost,
        timesWorn,
        lastWornAt,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of ClothingItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClothingItemModelImplCopyWith<_$ClothingItemModelImpl> get copyWith =>
      __$$ClothingItemModelImplCopyWithImpl<_$ClothingItemModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ClothingItemModelImplToJson(
      this,
    );
  }
}

abstract class _ClothingItemModel implements ClothingItemModel {
  const factory _ClothingItemModel(
      {required final String id,
      @JsonKey(name: 'user_id') required final String userId,
      required final String name,
      required final String category,
      @JsonKey(name: 'season_tags') final List<String> seasonTags,
      @JsonKey(name: 'original_image_url') final String? originalImageUrl,
      @JsonKey(name: 'processed_image_url') final String? processedImageUrl,
      @JsonKey(name: 'dominant_colors') final List<DominantColor> dominantColors,
      final String? brand,
      final double? cost,
      @JsonKey(name: 'times_worn') final int timesWorn,
      @JsonKey(name: 'last_worn_at') final DateTime? lastWornAt,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'updated_at') final DateTime? updatedAt}) =
      _$ClothingItemModelImpl;

  factory _ClothingItemModel.fromJson(Map<String, dynamic> json) =
      _$ClothingItemModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String get name;
  @override
  String get category;
  @override
  @JsonKey(name: 'season_tags')
  List<String> get seasonTags;
  @override
  @JsonKey(name: 'original_image_url')
  String? get originalImageUrl;
  @override
  @JsonKey(name: 'processed_image_url')
  String? get processedImageUrl;
  @override
  @JsonKey(name: 'dominant_colors')
  List<DominantColor> get dominantColors;
  @override
  String? get brand;
  @override
  double? get cost;
  @override
  @JsonKey(name: 'times_worn')
  int get timesWorn;
  @override
  @JsonKey(name: 'last_worn_at')
  DateTime? get lastWornAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Computed: cost per wear based on [timesWorn] and [cost].
  @override
  double? get costPerWear;

  /// Create a copy of ClothingItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClothingItemModelImplCopyWith<_$ClothingItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
