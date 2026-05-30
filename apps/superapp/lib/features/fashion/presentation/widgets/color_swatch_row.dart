import 'package:flutter/material.dart';
import '../../utils/color_utils.dart';
import '../../data/models/models.dart';

/// A proportional horizontal bar showing the palette of dominant colors.
class ColorSwatchRow extends StatelessWidget {
  const ColorSwatchRow({super.key, required this.colors});
  final List<DominantColor> colors;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 28,
      child: Row(
        children: colors.map((c) {
          final color = ColorUtils.hexToColor(c.hex);
          final pct = (c.percentage * 100).toStringAsFixed(0);
          return Expanded(
            flex: (c.percentage * 100).round().clamp(1, 100),
            child: Tooltip(
              message: '${c.hex} — $pct%',
              child: Container(color: color),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A row of small color circles — used in compact contexts (cards, lists).
class ColorSwatchCircles extends StatelessWidget {
  const ColorSwatchCircles({
    super.key,
    required this.colors,
    this.size = 18,
    this.maxCount = 5,
  });

  final List<DominantColor> colors;
  final double size;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colors.take(maxCount).map((c) {
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: ColorUtils.hexToColor(c.hex),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
        );
      }).toList(),
    );
  }
}
