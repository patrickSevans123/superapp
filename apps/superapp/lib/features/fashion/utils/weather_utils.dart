import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../data/models/weather_model.dart';

/// Fetches current weather via OpenWeatherMap.
///
/// Uses [dotenv] for the API key. Falls back to mock data when no key is set.
class WeatherDatasource {
  WeatherDatasource(this._dio);

  final Dio _dio;

  Future<WeatherModel> fetchWeather({
    double? latitude,
    double? longitude,
  }) async {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'your-openweather-key-here') {
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
          'appid': apiKey,
        },
      );

      return WeatherModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      // Fallback to mock on error
      return _mockWeather();
    }
  }

  WeatherModel _mockWeather() {
    return WeatherModel(
      city: 'Jakarta',
      temperatureCelsius: 28,
      condition: 'clear',
      conditionDescription: 'Clear sky',
      humidity: 65,
      iconCode: '01d',
    );
  }
}
