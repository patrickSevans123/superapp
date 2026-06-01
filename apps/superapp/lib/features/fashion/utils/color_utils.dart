import 'package:flutter/material.dart';

class ColorUtils {
  ColorUtils._();

  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  static Color hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Returns the complementary hue (offset by 180°)
  static Color complementary(Color color) {
    final hsl = HSLColor.fromColor(color);
    final newHue = (hsl.hue + 180) % 360;
    return hsl.withHue(newHue).toColor();
  }

  /// Returns two analogous colors (±30°)
  static List<Color> analogous(Color color) {
    final hsl = HSLColor.fromColor(color);
    return [
      hsl.withHue((hsl.hue + 30) % 360).toColor(),
      hsl.withHue((hsl.hue - 30 + 360) % 360).toColor(),
    ];
  }

  /// Checks if two colors are harmonious (complementary, analogous, or one is neutral)
  static bool areHarmonious(Color a, Color b) {
    if (_isNeutral(a) || _isNeutral(b)) return true;
    final hslA = HSLColor.fromColor(a);
    final hslB = HSLColor.fromColor(b);
    final diff = (hslA.hue - hslB.hue).abs();
    final normalized = diff > 180 ? 360 - diff : diff;
    // Analogous: within 45°, Complementary: 150–210°
    return normalized <= 45 || (normalized >= 150 && normalized <= 210);
  }

  static bool _isNeutral(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.saturation < 0.15;
  }
}
