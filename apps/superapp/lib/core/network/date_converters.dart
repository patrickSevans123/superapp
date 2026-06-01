import 'package:json_annotation/json_annotation.dart';

/// Tries to parse a DateTime from a string, returning null if it fails.
class FlexibleDateTimeConverter implements JsonConverter<DateTime?, String?> {
  const FlexibleDateTimeConverter();

  @override
  DateTime? fromJson(String? json) {
    if (json == null) return null;
    try {
      return DateTime.parse(json);
    } catch (_) {
      return null;
    }
  }

  @override
  String? toJson(DateTime? object) => object?.toIso8601String();
}
