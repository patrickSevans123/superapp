class WeatherModel {
  const WeatherModel({
    required this.city,
    required this.temperatureCelsius,
    required this.condition,
    required this.conditionDescription,
    required this.humidity,
    required this.iconCode,
  });

  final String city;
  final double temperatureCelsius;
  final String condition; // clear, clouds, rain, snow, etc.
  final String conditionDescription;
  final int humidity;
  final String iconCode;

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final weather = (json['weather'] as List).first as Map<String, dynamic>;
    final main = json['main'] as Map<String, dynamic>;

    return WeatherModel(
      city: json['name'] as String? ?? 'Unknown',
      temperatureCelsius: (main['temp'] as num).toDouble(),
      condition: (weather['main'] as String).toLowerCase(),
      conditionDescription: weather['description'] as String,
      humidity: (main['humidity'] as num).toInt(),
      iconCode: weather['icon'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'city': city,
        'temperature_celsius': temperatureCelsius,
        'condition': condition,
        'condition_description': conditionDescription,
        'humidity': humidity,
        'icon_code': iconCode,
      };

  String get temperatureBracket {
    if (temperatureCelsius < 5) return 'very_cold';
    if (temperatureCelsius < 15) return 'cold';
    if (temperatureCelsius < 25) return 'mild';
    return 'warm';
  }

  bool get isRaining =>
      condition.contains('rain') || condition.contains('drizzle');
  bool get isSnowing => condition.contains('snow');
}
