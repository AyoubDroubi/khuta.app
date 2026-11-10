import 'package:intl/intl.dart';

class WeekdayLabels {
  const WeekdayLabels._();

  static List<String> narrowMonFirst(String locale) {
    final n = DateFormat('', _resolve(locale)).dateSymbols.NARROWWEEKDAYS;
    return [n[1], n[2], n[3], n[4], n[5], n[6], n[0]];
  }

  static List<String> shortMonFirst(String locale) {
    final s = DateFormat('', _resolve(locale)).dateSymbols.SHORTWEEKDAYS;
    return [s[1], s[2], s[3], s[4], s[5], s[6], s[0]];
  }

  /// Languages whose "short" weekday names are full words (الاثنين, دوشنبه,
  /// יום ב׳) and so cannot fit a week-strip column. An explicit list, not a
  /// length rule: a length rule also caught Polish (niedz.) and produced two
  /// identical letters (p for poniedziałek and piątek).
  static const _letterLanguages = {'ar', 'fa', 'he'};

  static bool _usesLetters(String locale) =>
      _letterLanguages.contains(_resolve(locale).split(RegExp('[_-]')).first);

  /// Weekday names for narrow columns (week strips, heatmap headers, pickers):
  /// the locale's short names, or their one-letter forms for the languages
  /// above. All seven switch together, so a row never mixes the two.
  static List<String> compactMonFirst(String locale) =>
      _usesLetters(locale) ? narrowMonFirst(locale) : shortMonFirst(locale);

  static List<String> compactFrom(String locale, int weekStart) =>
      _usesLetters(locale)
          ? narrowFrom(locale, weekStart)
          : shortFrom(locale, weekStart);

  static List<String> shortSunFirst(String locale) =>
      List<String>.from(DateFormat('', _resolve(locale)).dateSymbols.SHORTWEEKDAYS);

  static List<String> narrowFrom(String locale, int weekStart) {
    final n = DateFormat('', _resolve(locale)).dateSymbols.NARROWWEEKDAYS;
    return _rotate(n, weekStart);
  }

  static List<String> shortFrom(String locale, int weekStart) {
    final s = DateFormat('', _resolve(locale)).dateSymbols.SHORTWEEKDAYS;
    return _rotate(s, weekStart);
  }

  static List<String> _rotate(List<String> sunFirst, int weekStart) =>
      List.generate(7, (i) {
        final weekday = ((weekStart - 1 + i) % 7) + 1;
        return sunFirst[weekday % 7];
      });

  static String _resolve(String locale) => locale.isEmpty ? 'en' : locale;
}

class MonthLabels {
  const MonthLabels._();

  static List<String> short(String locale) => [
        for (final month
            in DateFormat('', WeekdayLabels._resolve(locale)).dateSymbols.SHORTMONTHS)
          month.replaceAll('.', ''),
      ];

  static List<String> full(String locale) => List<String>.from(
        DateFormat('', WeekdayLabels._resolve(locale)).dateSymbols.MONTHS,
      );
}
