class CoverageDetail {
  final String tuition;
  final String monthlyStipend;
  final String currency;
  final String travel;
  final String accommodation;
  final String insurance;
  final String languageCourse;
  final List<String> other;

  const CoverageDetail({
    this.tuition = '',
    this.monthlyStipend = '',
    this.currency = '',
    this.travel = '',
    this.accommodation = '',
    this.insurance = '',
    this.languageCourse = '',
    this.other = const [],
  });

  factory CoverageDetail.fromJson(Map<String, dynamic> json) {
    return CoverageDetail(
      tuition: (json['tuition'] as String?) ?? '',
      monthlyStipend: (json['monthly_stipend'] as String?) ?? '',
      currency: (json['currency'] as String?) ?? '',
      travel: (json['travel'] as String?) ?? '',
      accommodation: (json['accommodation'] as String?) ?? '',
      insurance: (json['insurance'] as String?) ?? '',
      languageCourse: (json['language_course'] as String?) ?? '',
      other: (json['other'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tuition': tuition,
      'monthly_stipend': monthlyStipend,
      'currency': currency,
      'travel': travel,
      'accommodation': accommodation,
      'insurance': insurance,
      'language_course': languageCourse,
      'other': other,
    };
  }
}
