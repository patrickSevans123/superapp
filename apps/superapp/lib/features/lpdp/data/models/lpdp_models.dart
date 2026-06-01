// ─── LPDP Data Models ────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ─── LpdpProgram ────────────────────────────────────────────────────────────

class LpdpProgram {
  final String id;
  final String name;
  final String level; // Magister or Doktor
  final String bidangStrategis;
  final String universityName;
  final String country;
  final String? description;
  final String? duration;
  final String? language;
  final String? website;

  const LpdpProgram({
    required this.id,
    required this.name,
    required this.level,
    required this.bidangStrategis,
    required this.universityName,
    required this.country,
    this.description,
    this.duration,
    this.language,
    this.website,
  });

  factory LpdpProgram.fromJson(Map<String, dynamic> json) {
    return LpdpProgram(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      level: (json['level'] as String?) ?? '',
      bidangStrategis: (json['bidang_strategis'] as String?) ?? '',
      universityName: (json['university_name'] as String?) ?? '',
      country: (json['country'] as String?) ?? '',
      description: json['description'] as String?,
      duration: json['duration'] as String?,
      language: json['language'] as String?,
      website: json['website'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'bidang_strategis': bidangStrategis,
        'university_name': universityName,
        'country': country,
        'description': description,
        'duration': duration,
        'language': language,
        'website': website,
      };
}

// ─── LpdpUniversity ──────────────────────────────────────────────────────────

class LpdpUniversity {
  final String id;
  final String name;
  final String country;
  final String? website;
  final String? description;
  final String? ranking;
  final List<LpdpProgram> programs;

  const LpdpUniversity({
    required this.id,
    required this.name,
    required this.country,
    this.website,
    this.description,
    this.ranking,
    this.programs = const [],
  });

  int get programCount => programs.length;

  List<LpdpProgram> get magisterPrograms =>
      programs.where((p) => p.level == 'Magister').toList();

  List<LpdpProgram> get doktorPrograms =>
      programs.where((p) => p.level == 'Doktor').toList();

  Map<String, List<LpdpProgram>> get programsByBidang {
    final map = <String, List<LpdpProgram>>{};
    for (final p in programs) {
      map.putIfAbsent(p.bidangStrategis, () => []).add(p);
    }
    return map;
  }

  Set<String> get bidangStrategis =>
      programs.map((p) => p.bidangStrategis).toSet();

  factory LpdpUniversity.fromJson(Map<String, dynamic> json) {
    final programsList = (json['programs'] as List<dynamic>?)
            ?.map((e) => LpdpProgram.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return LpdpUniversity(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      country: (json['country'] as String?) ?? '',
      website: json['website'] as String?,
      description: json['description'] as String?,
      ranking: json['ranking'] as String?,
      programs: programsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country': country,
        'website': website,
        'description': description,
        'ranking': ranking,
        'programs': programs.map((e) => e.toJson()).toList(),
      };
}

// ─── LpdpStats ───────────────────────────────────────────────────────────────

class LpdpStats {
  final int totalUniversities;
  final int totalPrograms;
  final int totalCountries;
  final Map<String, int> programsByBidang;

  const LpdpStats({
    this.totalUniversities = 0,
    this.totalPrograms = 0,
    this.totalCountries = 0,
    this.programsByBidang = const {},
  });

  factory LpdpStats.fromJson(Map<String, dynamic> json) {
    final bidangRaw = json['programs_by_bidang'] as Map<String, dynamic>?;
    return LpdpStats(
      totalUniversities: (json['total_universities'] as num?)?.toInt() ?? 0,
      totalPrograms: (json['total_programs'] as num?)?.toInt() ?? 0,
      totalCountries: (json['total_countries'] as num?)?.toInt() ?? 0,
      programsByBidang: bidangRaw
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          const {},
    );
  }
}

// ─── Strategic Fields (Bidang Strategis) Info ────────────────────────────────

class LpdpBidangInfo {
  final String name;
  final String description;
  final IconData icon;

  const LpdpBidangInfo({
    required this.name,
    required this.description,
    required this.icon,
  });
}

const lpdpBidangList = [
  LpdpBidangInfo(
    name: 'Digitalisasi',
    description:
        'Penguasaan teknologi digital, AI, big data, dan transformasi digital untuk mendukung daya saing nasional.',
    icon: Icons.dns_outlined,
  ),
  LpdpBidangInfo(
    name: 'Energi',
    description:
        'Pengembangan energi terbarukan, ketahanan energi, dan efisiensi energi untuk masa depan berkelanjutan.',
    icon: Icons.bolt_outlined,
  ),
  LpdpBidangInfo(
    name: 'Hilirisasi',
    description:
        'Pengolahan sumber daya alam dalam negeri menjadi produk bernilai tambah tinggi untuk kemandirian industri.',
    icon: Icons.factory_outlined,
  ),
  LpdpBidangInfo(
    name: 'Kesehatan',
    description:
        'Penguatan sistem kesehatan, riset biomedis, farmasi, dan teknologi kesehatan untuk masyarakat.',
    icon: Icons.local_hospital_outlined,
  ),
  LpdpBidangInfo(
    name: 'Ketahanan Pangan',
    description:
        'Inovasi pertanian, agroteknologi, dan sistem pangan berkelanjutan untuk kemandirian pangan nasional.',
    icon: Icons.agriculture_outlined,
  ),
  LpdpBidangInfo(
    name: 'Maritim',
    description:
        'Pengembangan ekonomi kelautan, teknologi maritim, dan pengelolaan sumber daya laut berkelanjutan.',
    icon: Icons.directions_boat_outlined,
  ),
  LpdpBidangInfo(
    name: 'Material dan Manufaktur',
    description:
        'Riset material maju, nanoteknologi, dan manufaktur cerdas untuk daya saing industri nasional.',
    icon: Icons.handyman_outlined,
  ),
  LpdpBidangInfo(
    name: 'Pertahanan',
    description:
        'Penguasaan teknologi pertahanan, keamanan siber, dan sistem pertahanan negara yang mandiri.',
    icon: Icons.shield_outlined,
  ),
];

LpdpBidangInfo? findBidang(String name) {
  try {
    return lpdpBidangList.firstWhere(
      (b) => b.name.toLowerCase() == name.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}
