// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scholarship_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScholarshipModelImpl _$$ScholarshipModelImplFromJson(
        Map<String, dynamic> json) =>
    _$ScholarshipModelImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      provider: json['provider'] as String,
      description: json['description'] as String? ?? '',
      level:
          (json['level'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      destination: json['destination'] as String? ?? '',
      country: json['country'] as String? ?? '',
      coverage: json['coverage'] as String? ?? '',
      coverageDetail: json['coverage_detail'] == null
          ? const CoverageDetail()
          : CoverageDetail.fromJson(
              json['coverage_detail'] as Map<String, dynamic>),
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      openingDate: json['opening_date'] == null
          ? null
          : DateTime.parse(json['opening_date'] as String),
      url: json['url'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      fieldOfStudy: (json['field_of_study'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      fundingType: json['funding_type'] as String? ?? '',
      tips:
          (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      version: (json['version'] as num?)?.toInt() ?? 0,
      checksum: json['checksum'] as String? ?? '',
      foundAt: json['found_at'] == null
          ? null
          : DateTime.parse(json['found_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$ScholarshipModelImplToJson(
        _$ScholarshipModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'provider': instance.provider,
      'description': instance.description,
      'level': instance.level,
      'destination': instance.destination,
      'country': instance.country,
      'coverage': instance.coverage,
      'coverage_detail': instance.coverageDetail,
      'deadline': instance.deadline?.toIso8601String(),
      'opening_date': instance.openingDate?.toIso8601String(),
      'url': instance.url,
      'source_url': instance.sourceUrl,
      'requirements': instance.requirements,
      'field_of_study': instance.fieldOfStudy,
      'tags': instance.tags,
      'funding_type': instance.fundingType,
      'tips': instance.tips,
      'version': instance.version,
      'checksum': instance.checksum,
      'found_at': instance.foundAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
