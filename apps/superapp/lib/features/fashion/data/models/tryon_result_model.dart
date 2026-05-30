/// Represents a virtual try-on result for a clothing item.
class TryonResult {
  final String id;
  final String clothingItemId;
  final String? clothingName;
  final String? clothingCategory;
  final String? personImageUrl;
  final String? resultImageUrl;
  final String status;
  final DateTime createdAt;

  const TryonResult({
    required this.id,
    required this.clothingItemId,
    this.clothingName,
    this.clothingCategory,
    this.personImageUrl,
    this.resultImageUrl,
    required this.status,
    required this.createdAt,
  });

  factory TryonResult.fromJson(Map<String, dynamic> json) => TryonResult(
        id: json['id'] as String,
        clothingItemId: json['clothing_item_id'] as String,
        clothingName: json['clothing_name'] as String?,
        clothingCategory: json['clothing_category'] as String?,
        personImageUrl: json['person_image_url'] as String?,
        resultImageUrl: json['result_image_url'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clothing_item_id': clothingItemId,
        if (clothingName != null) 'clothing_name': clothingName,
        if (clothingCategory != null) 'clothing_category': clothingCategory,
        if (personImageUrl != null) 'person_image_url': personImageUrl,
        if (resultImageUrl != null) 'result_image_url': resultImageUrl,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TryonResult &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TryonResult(id: $id, clothingItemId: $clothingItemId, status: $status)';
}
