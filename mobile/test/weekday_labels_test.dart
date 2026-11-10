import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:khuta/core/i18n/date_labels.dart';
import 'package:khuta/l10n/app_localizations.dart';

// weekday names for narrow
// columns. In Arabic the "short" names are full words (الاثنين) and overflowed
// the week card by 79 dp; a first, length-based rule broke Polish (two "p").
void main() {
  final languages = [for (final l in AppLocalizations.supportedLocales) l.languageCode];
  const letterLanguages = {'ar', 'fa', 'he'};

  setUpAll(() async {
    for (final l in languages) {
      await initializeDateFormatting(l);
    }
  });

  test('every shipped language is covered by this test', () {
    expect(languages.toSet(), containsAll(['ar', 'de', 'en', 'es', 'fa', 'fr', 'he', 'hi', 'id', 'ko', 'nl', 'pl', 'pt', 'ru', 'uk', 'zh']));
  });

  test('in every shipped language the seven compact names are different from each other', () {
    for (final l in languages) {
      final names = WeekdayLabels.compactMonFirst(l);
      expect(names, hasLength(7), reason: l);
      expect(names.toSet(), hasLength(7), reason: '$l: $names');
    }
  });

  test('only Arabic, Persian and Hebrew change; every other language keeps its short names', () {
    for (final l in languages) {
      final compact = WeekdayLabels.compactMonFirst(l);
      if (letterLanguages.contains(l)) {
        expect(compact, WeekdayLabels.narrowMonFirst(l), reason: l);
      } else {
        expect(compact, WeekdayLabels.shortMonFirst(l), reason: l);
      }
    }
  });

  test('Polish keeps niedz., pon., wt. … (Monday and Friday stay different)', () {
    final pl = WeekdayLabels.compactMonFirst('pl');
    expect(pl, WeekdayLabels.shortMonFirst('pl'));
    expect(pl[0], isNot(pl[4]));
  });

  test('the one-letter forms are short enough for a column', () {
    for (final l in letterLanguages) {
      for (final name in WeekdayLabels.compactMonFirst(l)) {
        expect(name.runes.length, lessThanOrEqualTo(3), reason: '$l: $name');
      }
    }
    expect(WeekdayLabels.compactMonFirst('ar'), ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']);
  });

  test('a regional locale tag resolves to its language', () {
    expect(WeekdayLabels.compactMonFirst('ar_EG'), WeekdayLabels.narrowMonFirst('ar'));
    expect(WeekdayLabels.compactMonFirst('en'), ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
  });

  test('compactFrom rotates like shortFrom and respects the week start', () {
    final fromSunday = WeekdayLabels.compactFrom('en', DateTime.sunday);
    expect(fromSunday.first, 'Sun');
    expect(fromSunday.last, 'Sat');
    final ar = WeekdayLabels.compactFrom('ar', DateTime.saturday);
    expect(ar.first, 'س');
    expect(ar, hasLength(7));
    expect(WeekdayLabels.compactFrom('pl', DateTime.monday), WeekdayLabels.shortMonFirst('pl'));
  });
}
