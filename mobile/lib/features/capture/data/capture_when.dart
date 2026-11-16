/// Finds and resolves the day and time words in one clause.
///
/// All text passed in is already folded with `foldLetters`, so the keyword
/// tables below are written in folded spelling (ة as ه, أ إ آ as ا).
library;

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
}

class ResolvedWhen {
  const ResolvedWhen({this.day, this.minutes, this.timePassed = false});

  final DateTime? day;
  final int? minutes;
  final bool timePassed;
}

const _letters = r'؀-ۿa-z0-9';
const _period =
    r'(?:الصبح|صباحا|الفجر|العصر|الظهر|الضهر|المسا|مساءا|مساء|بالليل|الليل|am|pm)';
const _dayPart = r'(?:\s+(?:الصبح|العصر|الظهر|المسا|بالليل))?';

String _w(String body) => '(?<![$_letters])(?:$body)(?![$_letters])';

final _dayRules = <(DayWord, RegExp)>[
  (
    DayWord.dayAfterTomorrow,
    RegExp('${_w(r'بعد\s+(?:بكره|غد)|day\s+after\s+tomorrow')}$_dayPart'),
  ),
  (DayWord.tomorrow, RegExp('${_w('بكره|غدا|tomorrow')}$_dayPart')),
  (DayWord.today, RegExp('${_w('اليوم|الليله|today|tonight')}$_dayPart')),
  (
    DayWord.sunday,
    RegExp('${_w(r'(?:يوم\s+(?:ال)?|ال)احد|sunday')}$_dayPart')
  ),
  (
    DayWord.monday,
    RegExp('${_w(r'(?:يوم\s+(?:ال)?|ال)(?:اثنين|اتنين)|monday')}$_dayPart'),
  ),
  (
    DayWord.tuesday,
    RegExp(
        '${_w(r'(?:يوم\s+)?(?:ال)?(?:ثلاثاء|ثلاثا|تلاتاء)|tuesday')}$_dayPart'),
  ),
  (
    DayWord.wednesday,
    RegExp('${_w(r'(?:يوم\s+)?(?:ال)?(?:اربعاء|اربعا)|wednesday')}$_dayPart'),
  ),
  (
    DayWord.thursday,
    RegExp('${_w(r'(?:يوم\s+)?(?:ال)?خميس|thursday')}$_dayPart')
  ),
  (DayWord.friday, RegExp('${_w(r'(?:يوم\s+)?(?:ال)?جمعه|friday')}$_dayPart')),
  (DayWord.saturday, RegExp('${_w(r'(?:يوم\s+)?(?:ال)?سبت|saturday')}$_dayPart')),
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

// Marker + digits, with an optional period word after.
final _timeMarked = RegExp(
  '(?<![$_letters])(?:الساعه|at)\\s*(\\d{1,2})(?::(\\d{2}))?(?!\\d)'
  '(?:\\s*($_period)(?![$_letters]))?',
);
// "2 pm" / "2:30 am".
final _timeAmPm = RegExp(
  '(?<![$_letters])(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)(?![$_letters])',
);
// "3:30" with a colon and optional period word.
final _timeColon = RegExp(
  '(?<![$_letters:])(\\d{1,2}):(\\d{2})(?!\\d)(?:\\s*($_period)(?![$_letters]))?',
);
// "الساعة تسعة الصبح".
final _timeWord = RegExp(
  '(?<![$_letters])الساعه\\s+($_hourWordPattern)(?![$_letters])'
  '(?:\\s*($_period)(?![$_letters]))?',
);

WhenMatch findWhen(String folded) {
  final spans = <(int, int)>[];

  // Day: earliest match; "after tomorrow" claims its words before "tomorrow".
  DayWord? day;
  var dayStart = -1;
  final claimed = <(int, int)>[];
  for (final (word, rx) in _dayRules) {
    for (final m in rx.allMatches(folded)) {
      final overlaps = claimed.any((c) => m.start < c.$2 && m.end > c.$1);
      if (overlaps) continue;
      claimed.add((m.start, m.end));
      if (day == null || m.start < dayStart) {
        day = word;
        dayStart = m.start;
      }
    }
  }
  if (day != null) {
    final span = claimed.firstWhere((c) => c.$1 == dayStart);
    spans.add(span);
  }

  // Time: earliest match among the four shapes.
  int? minutes;
  var midnight = false;
  RegExpMatch? best;
  String? bestKind;
  for (final (kind, rx) in [
    ('marked', _timeMarked),
    ('ampm', _timeAmPm),
    ('colon', _timeColon),
    ('word', _timeWord),
  ]) {
    final m = rx.firstMatch(folded);
    if (m != null && (best == null || m.start < best.start)) {
      best = m;
      bestKind = kind;
    }
  }
  if (best != null) {
    int? hour;
    var minute = 0;
    String? period;
    if (bestKind == 'word') {
      final key = best.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
      hour = _hourWords[key];
      period = best.group(2);
    } else if (bestKind == 'ampm') {
      hour = int.parse(best.group(1)!);
      minute = int.tryParse(best.group(2) ?? '0') ?? 0;
      period = best.group(3);
    } else {
      hour = int.parse(best.group(1)!);
      minute = int.tryParse(best.group(2) ?? '0') ?? 0;
      period = best.group(3);
    }
    if (hour != null && hour <= 23 && minute <= 59) {
      final r = _applyPeriod(hour, period);
      minutes = r.$1 * 60 + minute;
      midnight = r.$2;
      spans.add((best.start, best.end));
    }
  }

  return WhenMatch(
    day: day,
    minutes: minutes,
    midnightNight: midnight,
    spans: spans,
  );
}

/// Returns the 24-hour hour, and whether it is a small hour of the night after
/// the named day.
(int, bool) _applyPeriod(int hour, String? period) {
  switch (period) {
    case 'الصبح':
    case 'صباحا':
    case 'الفجر':
    case 'am':
      return (hour == 12 ? 0 : hour, false);
    case 'الظهر':
    case 'الضهر':
      return (hour >= 1 && hour <= 5 ? hour + 12 : hour, false);
    case 'بالليل':
    case 'الليل':
      if (hour == 12) return (0, true);
      if (hour >= 1 && hour <= 5) return (hour, true);
      return (hour < 12 ? hour + 12 : hour, false);
    case 'العصر':
    case 'المسا':
    case 'مساء':
    case 'مساءا':
    case 'pm':
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
  var day = resolveDay(m.day, today: today);
  final minutes = m.minutes;
  if (minutes == null) return ResolvedWhen(day: day);

  if (m.midnightNight) {
    final base = day ?? DateTime(today.year, today.month, today.day);
    return ResolvedWhen(
      day: DateTime(base.year, base.month, base.day + 1),
      minutes: minutes,
    );
  }

  DateTime at(DateTime d) =>
      DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);

  if (m.day == null) {
    final base = DateTime(today.year, today.month, today.day);
    final passed = at(base).isBefore(now);
    day = passed ? DateTime(base.year, base.month, base.day + 1) : base;
    return ResolvedWhen(day: day, minutes: minutes);
  }
  final flagged = m.day == DayWord.today && at(day!).isBefore(now);
  return ResolvedWhen(day: day, minutes: minutes, timePassed: flagged);
}
