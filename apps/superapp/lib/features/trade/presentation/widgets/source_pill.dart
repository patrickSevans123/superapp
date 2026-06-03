/// Pill colour + label for a research-report source.
///
/// Centralised so the same colour/label pair is used by the list
/// card and the detail screen header.
library;

import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/research_report_source.dart';

class SourceStyle {
  final Color color;
  final String label;
  const SourceStyle({required this.color, required this.label});

  static SourceStyle forSource(ResearchReportSource? source) {
    switch (source) {
      case ResearchReportSource.samuel:
        return const SourceStyle(
          // Reuse the app's primary accent instead of duplicating the
          // 0xFF8B5CF6 literal — keeps the palette in one place.
          color: AppColors.accent,
          label: 'SAMUEL',
        );
      case ResearchReportSource.mandiri:
        return const SourceStyle(
          color: Color(0xFFFB7185), // rose – Mandiri Sekuritas
          label: 'MANDIRI',
        );
      case ResearchReportSource.kiwoom:
        return const SourceStyle(
          color: Color(0xFF38BDF8), // sky – Kiwoom
          label: 'KIWOOM',
        );
      case ResearchReportSource.rk:
        return const SourceStyle(
          color: Color(0xFF34D399), // emerald – Reliance / RK
          label: 'RK',
        );
      case ResearchReportSource.revalue:
        return const SourceStyle(
          color: Color(0xFFF59E0B), // amber – Revalue
          label: 'REVALUE',
        );
      case null:
        return const SourceStyle(
          color: AppColors.stone,
          label: 'OTHER',
        );
    }
  }
}

/// Compact pill that colour-codes a research report's source.
class SourcePill extends StatelessWidget {
  final ResearchReportSource? source;
  final double fontSize;
  const SourcePill({super.key, required this.source, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final s = SourceStyle.forSource(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: s.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: s.color,
        ),
      ),
    );
  }
}
