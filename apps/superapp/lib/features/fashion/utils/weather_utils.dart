import 'package:dio/dio.dart';

import '../data/models/weather_model.dart';

/// Fetches current weather via OpenWeatherMap.
///
/// The API key is provided at build time via `--dart-define`:
///   flutter run --dart-define=OPENWEATHER_API_KEY=your-key
///
/// Falls back to mock data when no key is set.
class WeatherDatasource {
  WeatherDatasource(this._dio);

  final Dio _dio;

  static const String _apiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: '',
  );

  Future<WeatherModel> fetchWeather({
    double? latitude,
    double? longitude,
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'your-openweather-key-here') {
      return _mockWeather();
    }

    try {
      final lat = latitude ?? -6.2088; // Default: Jakarta
      final lon = longitude ?? 106.8456;

      final response = await _dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'units': 'metric',
          'appid': _apiKey,
        },
      );

      return WeatherModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      // Fallback to mock on error
      return _mockWeather();
    }
  }

  WeatherModel _mockWeather() {
    return const WeatherModel(
      city: 'Jakarta',
      temperatureCelsius: 28,
      condition: 'clear',
      conditionDescription: 'Clear sky',
      humidity: 65,
      iconCode: '01d',
    );
  }
}
