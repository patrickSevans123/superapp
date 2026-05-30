// ─── Scholarship Riverpod Providers ───────────────────────────────────────

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/scholarship_model.dart';
import '../../data/models/coverage_detail.dart';

// ─── Browse Filter State (UI layer — separate from repository filter) ────

class BrowseFilters {
  final String search;
  final String level;
  final String country;
  final String funding;

  const BrowseFilters({
    this.search = '',
    this.level = 'All',
    this.country = 'All',
    this.funding = 'All',
  });

  BrowseFilters copyWith({
    String? search,
    String? level,
    String? country,
    String? funding,
  }) {
    return BrowseFilters(
      search: search ?? this.search,
      level: level ?? this.level,
      country: country ?? this.country,
      funding: funding ?? this.funding,
    );
  }

  bool get hasActiveFilters =>
      search.isNotEmpty ||
      level != 'All' ||
      country != 'All' ||
      funding != 'All';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowseFilters &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          level == other.level &&
          country == other.country &&
          funding == other.funding;

  @override
  int get hashCode => Object.hash(search, level, country, funding);
}

// ─── Browse Filters Notifier ─────────────────────────────────────────────

class BrowseFiltersNotifier extends StateNotifier<BrowseFilters> {
  BrowseFiltersNotifier() : super(const BrowseFilters());

  Timer? _debounce;

  void setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // When search changes, reset other filters to "All"
      state = BrowseFilters(search: value);
    });
  }

  void setLevel(String value) => state = state.copyWith(level: value);

  void setCountry(String value) => state = state.copyWith(country: value);

  void setFunding(String value) => state = state.copyWith(funding: value);

  void clearFilters() => state = const BrowseFilters();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final browseFiltersProvider =
    StateNotifierProvider<BrowseFiltersNotifier, BrowseFilters>((ref) {
  return BrowseFiltersNotifier();
});

// ─── Mock Data ───────────────────────────────────────────────────────────

List<ScholarshipModel> _mockScholarships = [
  ScholarshipModel(
    id: '1',
    title: 'DAAD Masters Scholarship for Developing Countries',
    provider: 'DAAD (German Academic Exchange Service)',
    country: 'Jerman',
    level: const ['S2', 'S3'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 8, 31),
    description:
        'The **DAAD Masters Scholarship** offers outstanding graduates from developing countries the chance to complete a Master\'s or PhD degree at a German university.\n\n### Benefits\n- Full tuition coverage\n- Monthly stipend of EUR 934\n- Health insurance\n- Travel allowance\n- Language course\n\n### Eligibility\nApplicants must hold a Bachelor\'s degree (completed within the last 6 years) and have at least two years of professional experience.',
    requirements: const [
      'Bachelor\'s degree with above-average grades',
      'At least 2 years of professional experience',
      'English or German language proficiency',
      'Strong motivation letter',
      'Two letters of recommendation',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Environmental Science',
      'Public Health',
      'Economics',
      'Social Sciences',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'EUR 934/mo',
      currency: 'EUR',
      travel: 'Covered',
      accommodation: 'Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.daad.de/en/',
    tips: const [
      'Start your application at least 6 months before the deadline',
      'Get your documents translated and notarized early',
      'Reach out to alumni on LinkedIn for application tips',
    ],
  ),
  ScholarshipModel(
    id: '2',
    title: 'MEXT Scholarship (Research)',
    provider: 'Ministry of Education, Japan',
    country: 'Jepang',
    level: const ['S2', 'S3'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 5, 15),
    description:
        'The **MEXT (Ministry of Education, Culture, Sports, Science and Technology)** Scholarship provides full financial support for international students to study at Japanese universities.\n\n### What\'s Covered\n- Full tuition exemption\n- Monthly allowance of JPY 143,000-145,000\n- Round-trip airfare\n- Accommodation support\n- Language preparation course',
    requirements: const [
      'Bachelor\'s degree or equivalent',
      'Must be born on or after April 2, 1991',
      'Proficiency in English or Japanese',
      'Research proposal in intended field',
      'Letter of acceptance from a Japanese professor (recommended)',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Natural Sciences',
      'Social Sciences',
      'Humanities',
      'Agriculture',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'JPY 143,000/mo',
      currency: 'JPY',
      travel: 'Covered',
      accommodation: 'Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.mext.go.jp/en/',
    tips: const [
      'Contact prospective professors before applying',
      'Prepare a detailed research proposal',
      'Apply through the embassy recommendation route for higher success rates',
    ],
  ),
  ScholarshipModel(
    id: '3',
    title: 'Korean Government Scholarship Program (KGSP)',
    provider: 'National Institute for International Education (NIIED)',
    country: 'Korea Selatan',
    level: const ['S1', 'S2', 'S3'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 3, 31),
    description:
        'The **Korean Government Scholarship Program (KGSP)** invites international students to pursue undergraduate and graduate degrees in South Korea.\n\n### Benefits\n- Full tuition coverage\n- Monthly stipend of KRW 1,000,000\n- Korean language training (1 year)\n- Round-trip airfare\n- Settlement allowance',
    requirements: const [
      'High school diploma (for S1) or Bachelor\'s degree (for S2/S3)',
      'Under 25 years old (S1) or under 40 (S2/S3)',
      'Minimum GPA of 3.0/4.0 (or equivalent)',
      'Korean or English proficiency',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Information Technology',
      'Korean Studies',
      'International Relations',
      'Business',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'KRW 1,000,000/mo',
      currency: 'KRW',
      travel: 'Covered',
      accommodation: 'Covered',
      insurance: 'Covered',
      languageCourse: 'Covered',
    ),
    url: 'https://www.niied.go.kr/',
    tips: const [
      'The Korean language training year is a huge advantage',
      'Submit strong recommendation letters from Korean professors if possible',
      'Prepare for the interview',
    ],
  ),
  ScholarshipModel(
    id: '4',
    title: 'CSC Chinese Government Scholarship',
    provider: 'China Scholarship Council',
    country: 'Tiongkok',
    level: const ['S1', 'S2', 'S3'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 4, 15),
    description:
        'The **Chinese Government Scholarship (CSC)** supports international students pursuing degrees at top Chinese universities.\n\n### Coverage\n- Full tuition waiver\n- Monthly stipend: CNY 2,500-3,500\n- Comprehensive medical insurance\n- On-campus accommodation',
    requirements: const [
      'High school diploma (S1) or Bachelor\'s degree (S2/S3)',
      'Under 25 (S1), under 35 (S2), under 40 (S3)',
      'HSK 4 or English proficiency',
      'Research proposal for graduate applicants',
      'Two recommendation letters',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Medicine',
      'Chinese Language & Literature',
      'Economics',
      'Computer Science',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'CNY 2,500-3,500/mo',
      currency: 'CNY',
      travel: 'Covered',
      accommodation: 'Covered',
      insurance: 'Covered',
      languageCourse: 'Covered',
    ),
    url: 'https://www.csc.edu.cn/',
    tips: const [
      'Apply to multiple Chinese universities simultaneously',
      'HSK certification strengthens your application',
      'Research the university ranking for CSC slots',
    ],
  ),
  ScholarshipModel(
    id: '5',
    title: 'Erasmus+ Joint Master Degree',
    provider: 'European Union',
    country: 'Jerman',
    level: const ['S2'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 2, 28),
    description:
        '**Erasmus Mundus Joint Master Degrees (EMJMD)** are prestigious international study programs offered by a consortium of European universities.\n\n### What You Get\n- Full tuition coverage\n- Monthly stipend of EUR 1,400\n- Travel and installation costs\n- Health insurance',
    requirements: const [
      'Bachelor\'s degree (any discipline depending on program)',
      'Strong academic record',
      'English proficiency (IELTS 6.5+)',
      'Motivation letter',
      'Two recommendation letters',
    ],
    fieldOfStudy: const [
      'Environmental Science',
      'Computer Science',
      'Journalism',
      'Public Policy',
      'Engineering',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'EUR 1,400/mo',
      currency: 'EUR',
      travel: 'Covered',
      accommodation: 'Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://erasmus-plus.ec.europa.eu/',
    tips: const [
      'Each EMJMD program has its own application portal',
      'Explain why the multi-country format matters to you',
      'Apply to multiple programs',
    ],
  ),
  ScholarshipModel(
    id: '6',
    title: 'University of Melbourne Graduate Research Scholarships',
    provider: 'University of Melbourne',
    country: 'Australia',
    level: const ['S2', 'S3'],
    fundingType: 'Partial',
    deadline: DateTime(2026, 10, 31),
    description:
        'The **University of Melbourne Graduate Research Scholarship** supports high-achieving international students pursuing research degrees.\n\n### Coverage\n- Full tuition fee offset\n- Living allowance of AUD 37,000 per year\n- Relocation grant and OSHC',
    requirements: const [
      'Four-year Bachelor\'s degree or Master\'s degree',
      'Research proposal aligned with a faculty member',
      'Minimum GPA of 3.5/4.0 or equivalent',
      'English proficiency (IELTS 7.0+)',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Sciences',
      'Medicine',
      'Arts & Humanities',
      'Business',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'AUD 3,083/mo',
      currency: 'AUD',
      travel: 'Not Covered',
      accommodation: 'Not Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://scholarships.unimelb.edu.au/',
    tips: const [
      'Contact potential supervisors before applying',
      'Highlight your research experience and publications',
      'Apply for external funding to supplement',
    ],
  ),
  ScholarshipModel(
    id: '7',
    title: 'Singapore International Graduate Award (SINGA)',
    provider: 'A*STAR & NTU & NUS',
    country: 'Singapura',
    level: const ['S3'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 6, 1),
    description:
        'The **Singapore International Graduate Award (SINGA)** offers PhD training in biomedical sciences, engineering, and physical sciences.\n\n### Benefits\n- Full tuition fees\n- Monthly stipend of SGD 2,200\n- Airfare grant and settlement allowance\n- Medical insurance',
    requirements: const [
      'Bachelor\'s degree with honors (or equivalent)',
      'Strong academic track record',
      'English proficiency (IELTS 6.5+)',
      'Research proposal',
      'Two academic referees',
    ],
    fieldOfStudy: const [
      'Biomedical Sciences',
      'Engineering',
      'Physical Sciences',
      'Information Technology',
      'Materials Science',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'SGD 2,200/mo',
      currency: 'SGD',
      travel: 'Covered',
      accommodation: 'Not Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.a-star.edu.sg/SINGA',
    tips: const [
      'Choose your research project carefully',
      'Reach out to potential supervisors before applying',
      'Prepare scanned documents in advance',
    ],
  ),
  ScholarshipModel(
    id: '8',
    title: 'Chevening Scholarships',
    provider: 'UK Government',
    country: 'Inggris',
    level: const ['S2'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 11, 5),
    description:
        '**Chevening Scholarships** are the UK Government\'s global scholarship programme for outstanding professionals to study a one-year Master\'s degree in the UK.\n\n### What\'s Included\n- Full tuition fees\n- Monthly living allowance\n- Economy travel to/from the UK\n- Networking events and leadership development',
    requirements: const [
      'Bachelor\'s degree (upper second class honors or equivalent)',
      'At least 2 years of work experience',
      'English proficiency (IELTS 6.5+)',
      'Apply to 3 eligible UK university courses',
      'Strong leadership potential',
    ],
    fieldOfStudy: const [
      'Public Policy',
      'International Development',
      'Law',
      'Business Administration',
      'Environmental Studies',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'GBP 1,500/mo',
      currency: 'GBP',
      travel: 'Covered',
      accommodation: 'Not Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.chevening.org/',
    tips: const [
      'Your essays are the most important part',
      'Choose courses strategically from at least 2 universities',
      'Demonstrate leadership through concrete examples',
    ],
  ),
  ScholarshipModel(
    id: '9',
    title: 'Fulbright Master\'s Degree Program',
    provider: 'AMINEF (American Indonesian Exchange Foundation)',
    country: 'Amerika Serikat',
    level: const ['S2'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 7, 15),
    description:
        'The **Fulbright Master\'s Degree Program** provides scholarships for Indonesian citizens to pursue Master\'s degrees in the United States.\n\n### Benefits\n- Full tuition coverage\n- Monthly stipend\n- Round-trip airfare\n- Health insurance',
    requirements: const [
      'Indonesian citizen (not US permanent resident)',
      'Bachelor\'s degree with minimum GPA of 3.0',
      'English proficiency (TOEFL 580+)',
      'Strong academic and professional record',
      'Commitment to return to Indonesia after program completion',
    ],
    fieldOfStudy: const [
      'Education',
      'Economics',
      'Environmental Science',
      'Public Health',
      'Communication',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'USD 2,000/mo',
      currency: 'USD',
      travel: 'Covered',
      accommodation: 'Not Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.aminef.or.id/',
    tips: const [
      'Be specific about universities and courses in your study plan',
      'Highlight your community involvement',
      'Prepare for a rigorous interview process',
    ],
  ),
  ScholarshipModel(
    id: '10',
    title: 'LPDP (Indonesia Endowment Fund for Education)',
    provider: 'Ministry of Finance, Republic of Indonesia',
    country: 'Indonesia',
    level: const ['S2', 'S3'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 6, 30),
    description:
        'The **LPDP Scholarship** is a competitive Indonesian government scholarship for high-achieving individuals to pursue Master\'s and PhD degrees at top universities worldwide.\n\n### Coverage\n- Full tuition fees\n- Monthly living allowance\n- Family allowance\n- Round-trip airfare\n- Health insurance',
    requirements: const [
      'Indonesian citizen (WNI)',
      'Bachelor\'s degree with minimum GPA 3.0',
      'English proficiency (TOEFL 550+ / IELTS 6.0+)',
      'Letter of acceptance (LoA) from a university',
      'Commitment to return to Indonesia after study',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Economics',
      'Law',
      'Public Health',
      'Education',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'IDR 5,000,000/mo',
      currency: 'IDR',
      travel: 'Covered',
      accommodation: 'Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.lpdp.kemenkeu.go.id/',
    tips: const [
      'Secure your LoA early',
      'The essay questions change each batch',
      'Prepare for psychological tests',
    ],
  ),
  ScholarshipModel(
    id: '11',
    title: 'Netherlands Fellowship Programmes (NFP)',
    provider: 'Nuffic',
    country: 'Belanda',
    level: const ['S2'],
    fundingType: 'Partial',
    deadline: DateTime(2026, 9, 1),
    description:
        'The **Netherlands Fellowship Programmes (NFP)** support professionals from developing countries to pursue short courses or Master\'s degrees in the Netherlands.\n\n### What\'s Covered (Partial)\n- Partial tuition fee (up to EUR 15,000)\n- Living allowance contribution\n- Visa and travel costs',
    requirements: const [
      'National of a developing country on the NFP list',
      'Bachelor\'s degree',
      'At least 3 years of relevant work experience',
      'Employed in an organization relevant to the study program',
    ],
    fieldOfStudy: const [
      'Agriculture',
      'Water Management',
      'Public Health',
      'Gender Studies',
      'Law',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Partial',
      monthlyStipend: 'EUR 750/mo',
      currency: 'EUR',
      travel: 'Covered',
      accommodation: 'Not Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.nuffic.nl/',
    tips: const [
      'Your employer must nominate you',
      'Choose a program directly related to your current job',
      'Highlight development impact in your application',
    ],
  ),
  ScholarshipModel(
    id: '12',
    title: 'Swiss Government Excellence Scholarship',
    provider: 'Swiss State Secretariat for Education, Research and Innovation',
    country: 'Swiss',
    level: const ['S3'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 12, 15),
    description:
        'The **Swiss Government Excellence Scholarship** promotes international exchange and research in Switzerland.\n\n### Benefits\n- Monthly stipend of CHF 1,920\n- Tuition exemption\n- Health insurance\n- Airfare contribution',
    requirements: const [
      'Master\'s degree or equivalent',
      'Research proposal agreed with a Swiss professor',
      'Under 35 years old',
      'English proficiency',
      'Two recommendation letters',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Natural Sciences',
      'Social Sciences',
      'Architecture',
      'Music & Arts',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'CHF 1,920/mo',
      currency: 'CHF',
      travel: 'Covered',
      accommodation: 'Not Covered',
      insurance: 'Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.sbfi.admin.ch/',
    tips: const [
      'Finding a host professor is the most critical step',
      'Your research proposal must be detailed and innovative',
      'French or German language skills are a bonus',
    ],
  ),
  ScholarshipModel(
    id: '13',
    title: 'Heinrich Boll Foundation Scholarship (S1)',
    provider: 'Heinrich Boll Foundation',
    country: 'Jerman',
    level: const ['S1'],
    fundingType: 'Partial',
    deadline: DateTime(2026, 3, 1),
    description:
        'The **Heinrich Boll Foundation Scholarship** supports international undergraduate students with outstanding academic records and strong social and political engagement.\n\n### Benefits (Partial)\n- Tuition support up to EUR 8,000/year\n- Monthly book allowance of EUR 300\n- Mentorship program',
    requirements: const [
      'High school diploma with excellent grades',
      'Active involvement in social, political, or environmental causes',
      'English or German proficiency',
      'Under 30 years old',
    ],
    fieldOfStudy: const [
      'Environmental Studies',
      'Political Science',
      'Sociology',
      'Media Studies',
      'Law',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Partial',
      monthlyStipend: 'EUR 300/mo',
      currency: 'EUR',
      travel: 'Not Covered',
      accommodation: 'Not Covered',
      insurance: 'Not Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.boell.de/en/scholarships',
    tips: const [
      'The foundation values green political values',
      'Volunteer experience is more important than grades',
      'Apply to universities partnered with the foundation',
    ],
  ),
  ScholarshipModel(
    id: '14',
    title: 'SUTD Undergraduate Scholarship',
    provider: 'Singapore University of Technology and Design',
    country: 'Singapura',
    level: const ['S1'],
    fundingType: 'Partial',
    deadline: DateTime(2026, 5, 31),
    description:
        'The **SUTD Undergraduate Scholarship** awards talented international students with financial support to pursue degrees in technology and design.\n\n### What\'s Covered\n- Up to 50% of tuition fees\n- Living allowance of SGD 4,000/year\n- Internship placement support',
    requirements: const [
      'High school diploma with strong STEM grades',
      'English proficiency (IELTS 6.5+)',
      'Portfolio or project experience (preferred)',
      'Interest in design innovation',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Design',
      'Architecture',
      'Information Technology',
      'Artificial Intelligence',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Partial (50%)',
      monthlyStipend: 'SGD 333/mo',
      currency: 'SGD',
      travel: 'Not Covered',
      accommodation: 'Not Covered',
      insurance: 'Not Covered',
      languageCourse: 'Not Covered',
    ),
    url: 'https://www.sutd.edu.sg/',
    tips: const [
      'Highlight project work in your application',
      'Practice creative problem-solving for the design challenge',
      'Apply early as scholarship slots are limited',
    ],
  ),
  ScholarshipModel(
    id: '15',
    title: 'MEXT Scholarship (Undergraduate)',
    provider: 'Ministry of Education, Japan',
    country: 'Jepang',
    level: const ['S1'],
    fundingType: 'Fully Funded',
    deadline: DateTime(2026, 6, 15),
    description:
        'The **MEXT Undergraduate Scholarship** provides comprehensive support for international students to study at Japanese universities as undergraduate students.\n\n### Benefits\n- Full tuition exemption\n- Monthly allowance of JPY 120,000\n- Round-trip airfare\n- Japanese language preparatory course (1 year)',
    requirements: const [
      'High school diploma or equivalent',
      'Born on or after April 2, 2002',
      'English or Japanese proficiency',
      'Strong academic record',
    ],
    fieldOfStudy: const [
      'Engineering',
      'Social Sciences',
      'Humanities',
      'Natural Sciences',
      'Japanese Studies',
    ],
    coverageDetail: CoverageDetail(
      tuition: 'Fully Covered',
      monthlyStipend: 'JPY 120,000/mo',
      currency: 'JPY',
      travel: 'Covered',
      accommodation: 'Covered',
      insurance: 'Covered',
      languageCourse: 'Covered',
    ),
    url: 'https://www.studyinjapan.go.jp/en/',
    tips: const [
      'The embassy recommendation route is most common',
      'The language preparatory year is intensive but essential',
      'Choose your major carefully',
    ],
  ),
];

// ─── Country Options Helper ──────────────────────────────────────────────

Set<String> _allCountries = {};
List<String> get allCountryOptions {
  if (_allCountries.isEmpty) {
    final ordered = <String>[
      'All',
      'Jerman',
      'Jepang',
      'Korea Selatan',
      'Tiongkok',
      'Amerika Serikat',
      'Inggris',
      'Australia',
      'Singapura',
      'Belanda',
      'Swiss',
      'Indonesia',
    ];
    for (final s in _mockScholarships) {
      if (!ordered.contains(s.country)) {
        ordered.add(s.country);
      }
    }
    _allCountries = ordered.toSet();
  }
  return _allCountries.toList();
}

// ─── Provider: Scholarships List ─────────────────────────────────────────

final scholarshipsProvider =
    FutureProvider.autoDispose<List<ScholarshipModel>>((ref) async {
  final filters = ref.watch(browseFiltersProvider);

  // Simulate network latency
  await Future.delayed(const Duration(milliseconds: 500));

  var results = _mockScholarships.where((s) {
    // Search filter
    if (filters.search.isNotEmpty) {
      final q = filters.search.toLowerCase();
      final matchesTitle = s.title.toLowerCase().contains(q);
      final matchesProvider = s.provider.toLowerCase().contains(q);
      final matchesCountry = s.country.toLowerCase().contains(q);
      if (!matchesTitle && !matchesProvider && !matchesCountry) {
        return false;
      }
    }

    // Level filter
    if (filters.level != 'All' && !s.level.contains(filters.level)) {
      return false;
    }

    // Country filter
    if (filters.country != 'All' && s.country != filters.country) {
      return false;
    }

    // Funding filter
    if (filters.funding != 'All' && s.fundingType != filters.funding) {
      return false;
    }

    return true;
  }).toList();

  return results;
});

// ─── Provider: Scholarship Detail ────────────────────────────────────────

final scholarshipDetailProvider =
    FutureProvider.autoDispose.family<ScholarshipModel, String>(
        (ref, id) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return _mockScholarships.firstWhere(
    (s) => s.id == id,
    orElse: () => throw Exception('Scholarship not found'),
  );
});
