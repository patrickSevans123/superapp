/// Represents a user's notification preferences.
///
/// All fields default to `true` (opted in) when a key is missing from JSON.
class NotificationPreferences {
  final bool tpHit;
  final bool slHit;
  final bool priceAlert;
  final bool msciAnnounce;
  final bool ftseNotice;
  final bool newReport;
  final bool planCreated;
  final bool scholarshipAlert;
  final bool fashionAlert;

  const NotificationPreferences({
    this.tpHit = true,
    this.slHit = true,
    this.priceAlert = true,
    this.msciAnnounce = true,
    this.ftseNotice = true,
    this.newReport = true,
    this.planCreated = true,
    this.scholarshipAlert = true,
    this.fashionAlert = true,
  });

  /// Creates a [NotificationPreferences] from a snake_case JSON map.
  ///
  /// Missing keys default to `true`.
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      tpHit: json['tp_hit'] as bool? ?? true,
      slHit: json['sl_hit'] as bool? ?? true,
      priceAlert: json['price_alert'] as bool? ?? true,
      msciAnnounce: json['msci_announce'] as bool? ?? true,
      ftseNotice: json['ftse_notice'] as bool? ?? true,
      newReport: json['new_report'] as bool? ?? true,
      planCreated: json['plan_created'] as bool? ?? true,
      scholarshipAlert: json['scholarship_alert'] as bool? ?? true,
      fashionAlert: json['fashion_alert'] as bool? ?? true,
    );
  }

  /// Converts this instance to a snake_case JSON map.
  Map<String, dynamic> toJson() {
    return {
      'tp_hit': tpHit,
      'sl_hit': slHit,
      'price_alert': priceAlert,
      'msci_announce': msciAnnounce,
      'ftse_notice': ftseNotice,
      'new_report': newReport,
      'plan_created': planCreated,
      'scholarship_alert': scholarshipAlert,
      'fashion_alert': fashionAlert,
    };
  }

  /// Returns a copy of this instance with the given fields replaced.
  NotificationPreferences copyWith({
    bool? tpHit,
    bool? slHit,
    bool? priceAlert,
    bool? msciAnnounce,
    bool? ftseNotice,
    bool? newReport,
    bool? planCreated,
    bool? scholarshipAlert,
    bool? fashionAlert,
  }) {
    return NotificationPreferences(
      tpHit: tpHit ?? this.tpHit,
      slHit: slHit ?? this.slHit,
      priceAlert: priceAlert ?? this.priceAlert,
      msciAnnounce: msciAnnounce ?? this.msciAnnounce,
      ftseNotice: ftseNotice ?? this.ftseNotice,
      newReport: newReport ?? this.newReport,
      planCreated: planCreated ?? this.planCreated,
      scholarshipAlert: scholarshipAlert ?? this.scholarshipAlert,
      fashionAlert: fashionAlert ?? this.fashionAlert,
    );
  }
}
