/// Allowed research-report source names. Mirrors the Go API's
/// `?source=` query param values. Add new sources here AND on the
/// backend (the `research_reports` table is keyed on these strings).
enum ResearchReportSource {
  samuel,
  mandiri,
  kiwoom,
  rk,
  revalue;

  /// Wire value sent to / received from the backend.
  String get apiValue {
    switch (this) {
      case ResearchReportSource.samuel:
        return 'samuel';
      case ResearchReportSource.mandiri:
        return 'mandiri';
      case ResearchReportSource.kiwoom:
        return 'kiwoom';
      case ResearchReportSource.rk:
        return 'rk';
      case ResearchReportSource.revalue:
        return 'revalue';
    }
  }

  /// Display label shown in chips / badges.
  String get label {
    switch (this) {
      case ResearchReportSource.samuel:
        return 'Samuel';
      case ResearchReportSource.mandiri:
        return 'Mandiri';
      case ResearchReportSource.kiwoom:
        return 'Kiwoom';
      case ResearchReportSource.rk:
        return 'RK';
      case ResearchReportSource.revalue:
        return 'Revalue';
    }
  }

  /// Lenient parse — the backend may send unknown values; we surface
  /// them as `null` so the UI can render a generic "Other" pill.
  static ResearchReportSource? tryParse(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    for (final s in ResearchReportSource.values) {
      if (s.apiValue == v) return s;
    }
    return null;
  }
}
