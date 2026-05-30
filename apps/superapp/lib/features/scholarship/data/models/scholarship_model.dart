import 'package:freezed_annotation/freezed_annotation.dart';

import 'coverage_detail.dart';

part 'scholarship_model.freezed.dart';
part 'scholarship_model.g.dart';

@freezed
class ScholarshipModel with _$ScholarshipModel {
  const factory ScholarshipModel({
    required String id,
    required String title,
    required String provider,
    @Default('') String description,
    @Default([]) List<String> level,
    @Default('') String destination,
    @Default('') String country,
    @Default('') String coverage,
    @JsonKey(name: 'coverage_detail')
    @Default(CoverageDetail())
    CoverageDetail coverageDetail,
    DateTime? deadline,
    @JsonKey(name: 'opening_date') DateTime? openingDate,
    @Default('') String url,
    @JsonKey(name: 'source_url') @Default('') String sourceUrl,
    @Default([]) List<String> requirements,
    @JsonKey(name: 'field_of_study') @Default([]) List<String> fieldOfStudy,
    @Default([]) List<String> tags,
    @JsonKey(name: 'funding_type') @Default('') String fundingType,
    @Default([]) List<String> tips,
    @Default(0) int version,
    @Default('') String checksum,
    @JsonKey(name: 'found_at') DateTime? foundAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ScholarshipModel;

  factory ScholarshipModel.fromJson(Map<String, dynamic> json) =>
      _$ScholarshipModelFromJson(json);
}
