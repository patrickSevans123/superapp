// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scholarship_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScholarshipModel _$ScholarshipModelFromJson(Map<String, dynamic> json) {
  return _ScholarshipModel.fromJson(json);
}

/// @nodoc
mixin _$ScholarshipModel {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get provider => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<String> get level => throw _privateConstructorUsedError;
  String get destination => throw _privateConstructorUsedError;
  String get country => throw _privateConstructorUsedError;
  String get coverage => throw _privateConstructorUsedError;
  @JsonKey(name: 'coverage_detail')
  CoverageDetail get coverageDetail => throw _privateConstructorUsedError;
  DateTime? get deadline => throw _privateConstructorUsedError;
  @JsonKey(name: 'opening_date')
  DateTime? get openingDate => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_url')
  String get sourceUrl => throw _privateConstructorUsedError;
  List<String> get requirements => throw _privateConstructorUsedError;
  @JsonKey(name: 'field_of_study')
  List<String> get fieldOfStudy => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'funding_type')
  String get fundingType => throw _privateConstructorUsedError;
  List<String> get tips => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  String get checksum => throw _privateConstructorUsedError;
  @JsonKey(name: 'found_at')
  DateTime? get foundAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ScholarshipModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScholarshipModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScholarshipModelCopyWith<ScholarshipModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScholarshipModelCopyWith<$Res> {
  factory $ScholarshipModelCopyWith(
          ScholarshipModel value, $Res Function(ScholarshipModel) then) =
      _$ScholarshipModelCopyWithImpl<$Res, ScholarshipModel>;
  @useResult
  $Res call(
      {String id,
      String title,
      String provider,
      String description,
      List<String> level,
      String destination,
      String country,
      String coverage,
      @JsonKey(name: 'coverage_detail') CoverageDetail coverageDetail,
      DateTime? deadline,
      @JsonKey(name: 'opening_date') DateTime? openingDate,
      String url,
      @JsonKey(name: 'source_url') String sourceUrl,
      List<String> requirements,
      @JsonKey(name: 'field_of_study') List<String> fieldOfStudy,
      List<String> tags,
      @JsonKey(name: 'funding_type') String fundingType,
      List<String> tips,
      int version,
      String checksum,
      @JsonKey(name: 'found_at') DateTime? foundAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$ScholarshipModelCopyWithImpl<$Res, $Val extends ScholarshipModel>
    implements $ScholarshipModelCopyWith<$Res> {
  _$ScholarshipModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScholarshipModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? provider = null,
    Object? description = null,
    Object? level = null,
    Object? destination = null,
    Object? country = null,
    Object? coverage = null,
    Object? coverageDetail = null,
    Object? deadline = freezed,
    Object? openingDate = freezed,
    Object? url = null,
    Object? sourceUrl = null,
    Object? requirements = null,
    Object? fieldOfStudy = null,
    Object? tags = null,
    Object? fundingType = null,
    Object? tips = null,
    Object? version = null,
    Object? checksum = null,
    Object? foundAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as List<String>,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      country: null == country
          ? _value.country
          : country // ignore: cast_nullable_to_non_nullable
              as String,
      coverage: null == coverage
          ? _value.coverage
          : coverage // ignore: cast_nullable_to_non_nullable
              as String,
      coverageDetail: null == coverageDetail
          ? _value.coverageDetail
          : coverageDetail // ignore: cast_nullable_to_non_nullable
              as CoverageDetail,
      deadline: freezed == deadline
          ? _value.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      openingDate: freezed == openingDate
          ? _value.openingDate
          : openingDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      sourceUrl: null == sourceUrl
          ? _value.sourceUrl
          : sourceUrl // ignore: cast_nullable_to_non_nullable
              as String,
      requirements: null == requirements
          ? _value.requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as List<String>,
      fieldOfStudy: null == fieldOfStudy
          ? _value.fieldOfStudy
          : fieldOfStudy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      fundingType: null == fundingType
          ? _value.fundingType
          : fundingType // ignore: cast_nullable_to_non_nullable
              as String,
      tips: null == tips
          ? _value.tips
          : tips // ignore: cast_nullable_to_non_nullable
              as List<String>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      checksum: null == checksum
          ? _value.checksum
          : checksum // ignore: cast_nullable_to_non_nullable
              as String,
      foundAt: freezed == foundAt
          ? _value.foundAt
          : foundAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ScholarshipModelImplCopyWith<$Res>
    implements $ScholarshipModelCopyWith<$Res> {
  factory _$$ScholarshipModelImplCopyWith(_$ScholarshipModelImpl value,
          $Res Function(_$ScholarshipModelImpl) then) =
      __$$ScholarshipModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String provider,
      String description,
      List<String> level,
      String destination,
      String country,
      String coverage,
      @JsonKey(name: 'coverage_detail') CoverageDetail coverageDetail,
      DateTime? deadline,
      @JsonKey(name: 'opening_date') DateTime? openingDate,
      String url,
      @JsonKey(name: 'source_url') String sourceUrl,
      List<String> requirements,
      @JsonKey(name: 'field_of_study') List<String> fieldOfStudy,
      List<String> tags,
      @JsonKey(name: 'funding_type') String fundingType,
      List<String> tips,
      int version,
      String checksum,
      @JsonKey(name: 'found_at') DateTime? foundAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$$ScholarshipModelImplCopyWithImpl<$Res>
    extends _$ScholarshipModelCopyWithImpl<$Res, _$ScholarshipModelImpl>
    implements _$$ScholarshipModelImplCopyWith<$Res> {
  __$$ScholarshipModelImplCopyWithImpl(_$ScholarshipModelImpl _value,
      $Res Function(_$ScholarshipModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of ScholarshipModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? provider = null,
    Object? description = null,
    Object? level = null,
    Object? destination = null,
    Object? country = null,
    Object? coverage = null,
    Object? coverageDetail = null,
    Object? deadline = freezed,
    Object? openingDate = freezed,
    Object? url = null,
    Object? sourceUrl = null,
    Object? requirements = null,
    Object? fieldOfStudy = null,
    Object? tags = null,
    Object? fundingType = null,
    Object? tips = null,
    Object? version = null,
    Object? checksum = null,
    Object? foundAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ScholarshipModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      level: null == level
          ? _value._level
          : level // ignore: cast_nullable_to_non_nullable
              as List<String>,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      country: null == country
          ? _value.country
          : country // ignore: cast_nullable_to_non_nullable
              as String,
      coverage: null == coverage
          ? _value.coverage
          : coverage // ignore: cast_nullable_to_non_nullable
              as String,
      coverageDetail: null == coverageDetail
          ? _value.coverageDetail
          : coverageDetail // ignore: cast_nullable_to_non_nullable
              as CoverageDetail,
      deadline: freezed == deadline
          ? _value.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      openingDate: freezed == openingDate
          ? _value.openingDate
          : openingDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      sourceUrl: null == sourceUrl
          ? _value.sourceUrl
          : sourceUrl // ignore: cast_nullable_to_non_nullable
              as String,
      requirements: null == requirements
          ? _value._requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as List<String>,
      fieldOfStudy: null == fieldOfStudy
          ? _value._fieldOfStudy
          : fieldOfStudy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      fundingType: null == fundingType
          ? _value.fundingType
          : fundingType // ignore: cast_nullable_to_non_nullable
              as String,
      tips: null == tips
          ? _value._tips
          : tips // ignore: cast_nullable_to_non_nullable
              as List<String>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      checksum: null == checksum
          ? _value.checksum
          : checksum // ignore: cast_nullable_to_non_nullable
              as String,
      foundAt: freezed == foundAt
          ? _value.foundAt
          : foundAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScholarshipModelImpl implements _ScholarshipModel {
  const _$ScholarshipModelImpl(
      {required this.id,
      required this.title,
      required this.provider,
      this.description = '',
      final List<String> level = const [],
      this.destination = '',
      this.country = '',
      this.coverage = '',
      @JsonKey(name: 'coverage_detail')
      this.coverageDetail = const CoverageDetail(),
      this.deadline,
      @JsonKey(name: 'opening_date') this.openingDate,
      this.url = '',
      @JsonKey(name: 'source_url') this.sourceUrl = '',
      final List<String> requirements = const [],
      @JsonKey(name: 'field_of_study')
      final List<String> fieldOfStudy = const [],
      final List<String> tags = const [],
      @JsonKey(name: 'funding_type') this.fundingType = '',
      final List<String> tips = const [],
      this.version = 0,
      this.checksum = '',
      @JsonKey(name: 'found_at') this.foundAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : _level = level,
        _requirements = requirements,
        _fieldOfStudy = fieldOfStudy,
        _tags = tags,
        _tips = tips;

  factory _$ScholarshipModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScholarshipModelImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String provider;
  @override
  @JsonKey()
  final String description;
  final List<String> _level;
  @override
  @JsonKey()
  List<String> get level {
    if (_level is EqualUnmodifiableListView) return _level;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_level);
  }

  @override
  @JsonKey()
  final String destination;
  @override
  @JsonKey()
  final String country;
  @override
  @JsonKey()
  final String coverage;
  @override
  @JsonKey(name: 'coverage_detail')
  final CoverageDetail coverageDetail;
  @override
  final DateTime? deadline;
  @override
  @JsonKey(name: 'opening_date')
  final DateTime? openingDate;
  @override
  @JsonKey()
  final String url;
  @override
  @JsonKey(name: 'source_url')
  final String sourceUrl;
  final List<String> _requirements;
  @override
  @JsonKey()
  List<String> get requirements {
    if (_requirements is EqualUnmodifiableListView) return _requirements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requirements);
  }

  final List<String> _fieldOfStudy;
  @override
  @JsonKey(name: 'field_of_study')
  List<String> get fieldOfStudy {
    if (_fieldOfStudy is EqualUnmodifiableListView) return _fieldOfStudy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fieldOfStudy);
  }

  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey(name: 'funding_type')
  final String fundingType;
  final List<String> _tips;
  @override
  @JsonKey()
  List<String> get tips {
    if (_tips is EqualUnmodifiableListView) return _tips;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tips);
  }

  @override
  @JsonKey()
  final int version;
  @override
  @JsonKey()
  final String checksum;
  @override
  @JsonKey(name: 'found_at')
  final DateTime? foundAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ScholarshipModel(id: $id, title: $title, provider: $provider, description: $description, level: $level, destination: $destination, country: $country, coverage: $coverage, coverageDetail: $coverageDetail, deadline: $deadline, openingDate: $openingDate, url: $url, sourceUrl: $sourceUrl, requirements: $requirements, fieldOfStudy: $fieldOfStudy, tags: $tags, fundingType: $fundingType, tips: $tips, version: $version, checksum: $checksum, foundAt: $foundAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScholarshipModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._level, _level) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.coverage, coverage) ||
                other.coverage == coverage) &&
            (identical(other.coverageDetail, coverageDetail) ||
                other.coverageDetail == coverageDetail) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.openingDate, openingDate) ||
                other.openingDate == openingDate) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl) &&
            const DeepCollectionEquality()
                .equals(other._requirements, _requirements) &&
            const DeepCollectionEquality()
                .equals(other._fieldOfStudy, _fieldOfStudy) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.fundingType, fundingType) ||
                other.fundingType == fundingType) &&
            const DeepCollectionEquality().equals(other._tips, _tips) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.checksum, checksum) ||
                other.checksum == checksum) &&
            (identical(other.foundAt, foundAt) || other.foundAt == foundAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        title,
        provider,
        description,
        const DeepCollectionEquality().hash(_level),
        destination,
        country,
        coverage,
        coverageDetail,
        deadline,
        openingDate,
        url,
        sourceUrl,
        const DeepCollectionEquality().hash(_requirements),
        const DeepCollectionEquality().hash(_fieldOfStudy),
        const DeepCollectionEquality().hash(_tags),
        fundingType,
        const DeepCollectionEquality().hash(_tips),
        version,
        checksum,
        foundAt,
        updatedAt
      ]);

  /// Create a copy of ScholarshipModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScholarshipModelImplCopyWith<_$ScholarshipModelImpl> get copyWith =>
      __$$ScholarshipModelImplCopyWithImpl<_$ScholarshipModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScholarshipModelImplToJson(
      this,
    );
  }
}

abstract class _ScholarshipModel implements ScholarshipModel {
  const factory _ScholarshipModel(
          {required final String id,
          required final String title,
          required final String provider,
          final String description,
          final List<String> level,
          final String destination,
          final String country,
          final String coverage,
          @JsonKey(name: 'coverage_detail') final CoverageDetail coverageDetail,
          final DateTime? deadline,
          @JsonKey(name: 'opening_date') final DateTime? openingDate,
          final String url,
          @JsonKey(name: 'source_url') final String sourceUrl,
          final List<String> requirements,
          @JsonKey(name: 'field_of_study') final List<String> fieldOfStudy,
          final List<String> tags,
          @JsonKey(name: 'funding_type') final String fundingType,
          final List<String> tips,
          final int version,
          final String checksum,
          @JsonKey(name: 'found_at') final DateTime? foundAt,
          @JsonKey(name: 'updated_at') final DateTime? updatedAt}) =
      _$ScholarshipModelImpl;

  factory _ScholarshipModel.fromJson(Map<String, dynamic> json) =
      _$ScholarshipModelImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get provider;
  @override
  String get description;
  @override
  List<String> get level;
  @override
  String get destination;
  @override
  String get country;
  @override
  String get coverage;
  @override
  @JsonKey(name: 'coverage_detail')
  CoverageDetail get coverageDetail;
  @override
  DateTime? get deadline;
  @override
  @JsonKey(name: 'opening_date')
  DateTime? get openingDate;
  @override
  String get url;
  @override
  @JsonKey(name: 'source_url')
  String get sourceUrl;
  @override
  List<String> get requirements;
  @override
  @JsonKey(name: 'field_of_study')
  List<String> get fieldOfStudy;
  @override
  List<String> get tags;
  @override
  @JsonKey(name: 'funding_type')
  String get fundingType;
  @override
  List<String> get tips;
  @override
  int get version;
  @override
  String get checksum;
  @override
  @JsonKey(name: 'found_at')
  DateTime? get foundAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of ScholarshipModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScholarshipModelImplCopyWith<_$ScholarshipModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
