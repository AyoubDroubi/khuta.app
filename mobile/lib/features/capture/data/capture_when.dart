/// Finds and resolves the day and time words in one clause.
///
/// All text passed in is already stripped of marks and folded with
/// `foldLetters`, so the keyword tables below are written in folded spelling
/// (ة as ه, أ إ آ as ا, no diacritics).
library;

import 'package:khuta/features/capture/data/capture_normalize.dart';

enum DayWord {
  today,
  tomorrow,
  dayAfterTomorrow,
  sunday,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
}

class WhenMatch {
  const WhenMatch({
    this.day,
    this.minutes,
    this.midnightNight = false,
    this.spans = const [],
  });

  final DayWord? day;
  final int? minutes;

  /// The time belongs to the night after the named day (12 at night, or 1 to
  /// 5 at night), so the resolved day is one day later.
  final bool midnightNight;

  /// `[start, end)` ranges of the folded text to cut from the title.
  final List<(int, int)> spans;

  /// This match with the gaps filled from [other] (a later clause that only
  /// carried a day or a time).
  WhenMatch merge(WhenMatch other) => WhenMatch(
        day: day ?? other.day,
        minutes: minutes ?? other.minutes,
        midnightNight: minutes != null ? midnightNight : other.midnightNight,
        spans: spans,
      );
}

class ResolvedWhen {
  const ResolvedWhen({this.day, this.minutes, this.timePassed = false});

  final DateTime? day;
  final int? minutes;
  final bool timePassed;
}

const _letters = captureLetters;

const _dayPeriodWords =
    'الصبح|الصباح|العصر|الظهر|المسا|المغرب|العشاء|العشا|بالليل';
const _periodWords =
    'الصبح|الصباح|صباحا|الفجر|بعد\\s+الظهر|الظهر|الضهر|العصر|المغرب|العشاء|'
    'العشا|المسا|مساءا|مساء|بالليل|الليل';
const _ampm = r'am|pm|a\.m\.?|p\.m\.?';
const _period = '(?:$_periodWords|$_ampm)';

// "و نص" (half), "و ربع" (quarter), "الا ربع" (a quarter to).
const _adjust = '(?:\\s*(?:و\\s*(?<adj>نصف|نص|ربع|ثلث)(?![$_letters])|'
    'الا\\s+(?<less>ربع|ثلث)(?![$_letters])))?';

const _w = wordBounded;

const _dayPart = '(?:\\s+(?<part>$_dayPeriodWords))?';

const _wd = r'(?:يوم\s+(?:ال)?|ال)';

// "غدا" is tomorrow, but after a cooking or eating verb it is lunch.
const _ghada = r'(?<!(?:اطبخ|نطبخ|بطبخ|طبخ|اعمل|نعمل|بعمل|بنعمل|حضر|نحضر|جهز|نجهز|'
    r'سوي|اسوي|نسوي|ناكل|اكل|بناكل|ماكل|تغدي|نتغدي)\s+)غدا';

final _dayRules = <(DayWord, RegExp)>[
  (
    DayWord.dayAfterTomorrow,
    RegExp(
      '${_w(r'بعد\s+(?:بكره|بكرا|بكري|غدا|(?:ال)?غد)|day\s+after\s+tomorrow')}'
      '$_dayPart',
    ),
  ),
  (
    DayWord.tomorrow,
    RegExp(
      '${_w('(?:في\\s+)?(?:بكره|بكرا|بكري|$_ghada|الغد|غد)|tomorrow')}$_dayPart',
    ),
  ),
  (DayWord.today, RegExp('${_w('اليوم|الليله|today|tonight')}$_dayPart')),
  (DayWord.sunday, RegExp('${_w('$_wdاحد|sunday')}$_dayPart')),
  (DayWord.monday, RegExp('${_w('$_wd(?:اثنين|اتنين)|monday')}$_dayPart')),
  (
    DayWord.tuesday,
    RegExp('${_w('$_wd(?:ثلاثاء|ثلاثا|تلاتاء|تلاتا)|tuesday')}$_dayPart'),
  ),
  (
    DayWord.wednesday,
    RegExp('${_w('$_wd(?:اربعاء|اربعا)|wednesday')}$_dayPart'),
  ),
  (DayWord.thursday, RegExp('${_w('$_wdخميس|thursday')}$_dayPart')),
  (DayWord.friday, RegExp('${_w('$_wdجمعه|friday')}$_dayPart')),
  (DayWord.saturday, RegExp('${_w('$_wdسبت|saturday')}$_dayPart')),
];

const _hourWords = <String, int>{
  'واحده': 1,
  'وحده': 1,
  'اثنين': 2,
  'اتنين': 2,
  'اثنتين': 2,
  'ثنتين': 2,
  'ثلاثه': 3,
  'تلاته': 3,
  'اربعه': 4,
  'خمسه': 5,
  'سته': 6,
  'سبعه': 7,
  'ثمانيه': 8,
  'تمانيه': 8,
  'تسعه': 9,
  'عشره': 10,
  'احد عشر': 11,
  'احدعشر': 11,
  'اثنا عشر': 12,
  'اثنعشر': 12,
};

final _hourWordPattern = (_hourWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length)))
    .map((w) => w.replaceAll(' ', r'\s+'))
    .join('|');

final _perOpt = '(?:\\s*(?<per>$_period)(?![$_letters]))?';

// "الساعة 5 [ونص] [العصر]".
final _timeAr = RegExp(
  '(?<![$_letters])الساعه\\s*(?<h>\\d{1,2})(?::(?<mi>\\d{2}))?(?!\\d)'
  '$_adjust$_perOpt',
);
// "الساعة تسعة [الصبح]".
final _timeWord = RegExp(
  '(?<![$_letters])الساعه\\s+(?<w>$_hourWordPattern)(?![$_letters])'
  '$_adjust$_perOpt',
);
// "2 pm", "at 2 pm", "3pm", "5 p.m.": am/pm is required.
final _timeAmPm = RegExp(
  '(?<![$_letters])(?:at\\s+)?(?<h>\\d{1,2})(?::(?<mi>\\d{2}))?\\s*'
  '(?<per>$_ampm)(?![$_letters])',
);
// "at 3:30".
final _timeAtColon = RegExp(
  '(?<![$_letters])at\\s+(?<h>\\d{1,2}):(?<mi>\\d{2})(?!\\d)$_perOpt',
);
// "3:30 العصر": a colon time needs a period word.
final _timeColon = RegExp(
  '(?<![$_letters:])(?<h>\\d{1,2}):(?<mi>\\d{2})(?!\\d)\\s*'
  '(?<per>$_period)(?![$_letters])',
);

WhenMatch findWhen(String folded) {
  final spans = <(int, int)>[];

  // Day: earliest match; "after tomorrow" claims its words before "tomorrow".
  DayWord? day;
  RegExpMatch? dayMatch;
  final claimed = <(int, int)>[];
  for (final (word, rx) in _dayRules) {
    for (final m in rx.allMatches(folded)) {
      if (claimed.any((c) => m.start < c.$2 && m.end > c.$1)) continue;
      claimed.add((m.start, m.end));
      if (dayMatch == null || m.start < dayMatch.start) {
        day = word;
        dayMatch = m;
      }
    }
  }
  String? dayPeriod;
  if (dayMatch != null) {
    spans.add((dayMatch.start, dayMatch.end));
    dayPeriod = dayMatch.namedGroup('part');
    final text = dayMatch.group(0)!;
    if (dayPeriod == null && (text.contains('الليله') || text.contains('tonight'))) {
      dayPeriod = 'بالليل';
    }
  }

  // Time: the earliest match among the shapes.
  RegExpMatch? best;
  var kind = '';
  for (final (k, rx) in [
    ('ar', _timeAr),
    ('word', _timeWord),
    ('ampm', _timeAmPm),
    ('atcolon', _timeAtColon),
    ('colon', _timeColon),
  ]) {
    final m = rx.firstMatch(folded);
    if (m != null && (best == null || m.start < best.start)) {
      best = m;
      kind = k;
    }
  }

  int? minutes;
  var midnight = false;
  if (best != null) {
    final int? hour = kind == 'word'
        ? _hourWords[best.namedGroup('w')!.replaceAll(RegExp(r'\s+'), ' ')]
        : int.parse(best.namedGroup('h')!);
    final minute = int.tryParse(_group(best, 'mi') ?? '0') ?? 0;
    if (hour != null && hour <= 23 && minute <= 59) {
      final period = _group(best, 'per') ?? dayPeriod;
      final r = _applyPeriod(hour, period);
      var total = r.$1 * 60 + minute;
      final adj = _group(best, 'adj');
      final less = _group(best, 'less');
      var night = r.$2;
      if (adj != null) {
        total += adj.startsWith('نص') ? 30 : (adj == 'ربع' ? 15 : 20);
      } else if (less != null) {
        total -= less == 'ربع' ? 15 : 20;
        if (total < 0) {
          // "12 الا ربع بالليل": a quarter to midnight is late on the same day.
          total += 24 * 60;
          night = false;
        }
      }
      if (total >= 0 && total < 24 * 60) {
        minutes = total;
        midnight = night;
        spans.add((best.start, best.end));
      }
    }
  }

  return WhenMatch(
    day: day,
    minutes: minutes,
    midnightNight: midnight,
    spans: spans,
  );
}

String? _group(RegExpMatch m, String name) =>
    m.groupNames.contains(name) ? m.namedGroup(name) : null;

/// Returns the 24-hour hour, and whether it is a small hour of the night after
/// the named day.
(int, bool) _applyPeriod(int hour, String? period) {
  final key = period?.replaceAll(RegExp(r'\s+'), ' ').replaceAll('.', '');
  switch (key) {
    case 'الصبح':
    case 'الصباح':
    case 'صباحا':
    case 'الفجر':
    case 'am':
      return (hour == 12 ? 0 : hour, false);
    case 'الظهر':
    case 'الضهر':
      return (hour >= 1 && hour <= 5 ? hour + 12 : hour, false);
    case 'بعد الظهر':
    case 'العصر':
    case 'المسا':
    case 'مساء':
    case 'مساءا':
    case 'المغرب':
    case 'العشاء':
    case 'العشا':
    case 'pm':
      return (hour < 12 ? hour + 12 : hour, false);
    case 'بالليل':
    case 'الليل':
      if (hour == 12) return (0, true);
      if (hour >= 1 && hour <= 5) return (hour, true);
      return (hour < 12 ? hour + 12 : hour, false);
  }
  return (hour, false);
}

DateTime? resolveDay(DayWord? word, {required DateTime today}) {
  if (word == null) return null;
  final base = DateTime(today.year, today.month, today.day);
  switch (word) {
    case DayWord.today:
      return base;
    case DayWord.tomorrow:
      return DateTime(base.year, base.month, base.day + 1);
    case DayWord.dayAfterTomorrow:
      return DateTime(base.year, base.month, base.day + 2);
    default:
      final target = switch (word) {
        DayWord.monday => DateTime.monday,
        DayWord.tuesday => DateTime.tuesday,
        DayWord.wednesday => DateTime.wednesday,
        DayWord.thursday => DateTime.thursday,
        DayWord.friday => DateTime.friday,
        DayWord.saturday => DateTime.saturday,
        _ => DateTime.sunday,
      };
      var ahead = (target - base.weekday + 7) % 7;
      if (ahead == 0) ahead = 7;
      return DateTime(base.year, base.month, base.day + ahead);
  }
}

ResolvedWhen resolveWhen(
  WhenMatch m, {
  required DateTime today,
  required DateTime now,
}) {
  final day = resolveDay(m.day, today: today);
  final minutes = m.minutes;
  if (minutes == null) return ResolvedWhen(day: day);

  DateTime at(DateTime d) =>
      DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
  DateTime plus(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  if (m.day == null) {
    // A bare time is the next time that clock reading comes round.
    var d = DateTime(today.year, today.month, today.day);
    for (var i = 0; i < 3 && at(d).isBefore(now); i++) {
      d = plus(d, 1);
    }
    return ResolvedWhen(day: d, minutes: minutes);
  }
  if (m.midnightNight) {
    return ResolvedWhen(day: plus(day!, 1), minutes: minutes);
  }
  final flagged = m.day == DayWord.today && at(day!).isBefore(now);
  return ResolvedWhen(day: day, minutes: minutes, timePassed: flagged);
}
