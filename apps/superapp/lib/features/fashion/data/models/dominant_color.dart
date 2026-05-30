/// Represents a dominant color extracted from a clothing item image.
class DominantColor {
  final String hex;
  final double percentage;

  const DominantColor({required this.hex, required this.percentage});

  factory DominantColor.fromJson(Map<String, dynamic> json) => DominantColor(
        hex: json['hex'] as String,
        percentage: (json['percentage'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'hex': hex, 'percentage': percentage};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DominantColor &&
          runtimeType == other.runtimeType &&
          hex == other.hex &&
          percentage == other.percentage;

  @override
  int get hashCode => Object.hash(hex, percentage);

  @override
  String toString() => 'DominantColor(hex: $hex, percentage: $percentage)';
}
