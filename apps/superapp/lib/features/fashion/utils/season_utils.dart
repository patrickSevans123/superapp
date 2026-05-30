enum Season { spring, summer, autumn, winter }

class SeasonUtils {
  SeasonUtils._();

  static Season currentSeason() {
    final month = DateTime.now().month;
    return switch (month) {
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      9 || 10 || 11 => Season.autumn,
      _ => Season.winter,
    };
  }

  static String seasonName(Season season) => switch (season) {
        Season.spring => 'spring',
        Season.summer => 'summer',
        Season.autumn => 'autumn',
        Season.winter => 'winter',
      };

  static List<String> currentSeasonTags() {
    final season = currentSeason();
    // Include adjacent seasons for transitional items
    return switch (season) {
      Season.spring => ['spring', 'all-season'],
      Season.summer => ['summer', 'all-season'],
      Season.autumn => ['autumn', 'all-season'],
      Season.winter => ['winter', 'all-season'],
    };
  }
}
