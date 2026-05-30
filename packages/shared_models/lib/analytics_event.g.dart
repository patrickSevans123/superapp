// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnalyticsEventImpl _$$AnalyticsEventImplFromJson(Map<String, dynamic> json) =>
    _$AnalyticsEventImpl(
      name: json['name'] as String,
      module: json['module'] as String,
      properties: json['properties'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$AnalyticsEventImplToJson(
        _$AnalyticsEventImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'module': instance.module,
      'properties': instance.properties,
      'timestamp': instance.timestamp?.toIso8601String(),
    };
