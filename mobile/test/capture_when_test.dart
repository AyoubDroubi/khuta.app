import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/capture/data/capture_normalize.dart';
import 'package:khuta/features/capture/data/capture_when.dart';

// A Monday, 09:00.
final _today = DateTime(2026, 11, 16);
final _now = DateTime(2026, 11, 16, 9, 0);

ResolvedWhen _r(String text, {DateTime? today, DateTime? now}) => resolveWhen(
      findWhen(foldLetters(text)),
      today: today ?? _today,
      now: now ?? _now,
    );

DateTime _d(int day) => DateTime(2026, 11, day);

void main() {
  group('day words', () {
    test('tomorrow in three spellings', () {
      for (final t in ['بكرة', 'بكره', 'tomorrow']) {
        expect(_r(t).day, _d(17), reason: t);
      }
    });

    test('the day after tomorrow is not tomorrow', () {
      expect(_r('بعد بكرة').day, _d(18));
      expect(_r('بعد بكره عندي موعد').day, _d(18));
    });

    test('today words', () {
      for (final t in ['اليوم', 'الليلة', 'today']) {
        expect(_r(t).day, _d(16), reason: t);
      }
    });

    test('weekday names mean their next occurrence, never today', () {
      expect(_r('الخميس').day, _d(19));
      expect(_r('يوم الخميس').day, _d(19));
      expect(_r('الأحد').day, _d(22));
      expect(_r('الاثنين').day, _d(23));
      expect(_r('الإثنين').day, _d(23));
      expect(_r('الجمعة').day, _d(20));
      expect(_r('Friday').day, _d(20));
    });

    test('a sentence with no day word has no day', () {
      expect(_r('اشتري خبز').day, isNull);
      expect(_r('كلمة السر 1234').minutes, isNull);
    });
  });

  group('times', () {
    final cases = <String, int>{
      'الساعة 10 الصبح': 600,
      'الساعة 5 العصر': 1020,
      'الساعة 8 بالليل': 1200,
      'الساعة 7 المسا': 1140,
      'الساعة 12 الظهر': 720,
      'الساعة 1 الظهر': 780,
      'الساعة 3 العصر': 900,
      'الساعة 6 الصبح': 360,
      'at 2 pm': 840,
      '2 pm': 840,
      'الساعة 9:30 الصبح': 570,
      'الساعة 3:30 العصر': 930,
      'الساعة ٥ العصر': 1020,
      'الساعة تسعة الصبح': 540,
      'الساعة ثمانية بالليل': 1200,
      'الساعة 5': 300,
    };
    cases.forEach((text, minutes) {
      test('"$text" is $minutes minutes', () {
        expect(_r(text).minutes, minutes);
      });
    });

    test('impossible times are ignored', () {
      expect(_r('الساعة 25').minutes, isNull);
      expect(_r('الساعة 10:75').minutes, isNull);
    });

    test('a time on a DST-change date is still plain minutes', () {
      final dst = DateTime(2026, 3, 29);
      final r = _r('الأحد الساعة 2:30 الصبح',
          today: DateTime(2026, 3, 23), now: DateTime(2026, 3, 23, 9));
      expect(r.day, dst);
      expect(r.minutes, 150);
    });
  });

  group('midnight', () {
    test('12 at night is midnight at the end of the named day', () {
      final r = _r('بكرة الساعة 12 بالليل');
      expect(r.minutes, 0);
      expect(r.day, _d(18));
    });

    test('1 to 5 at night are small hours after the named day', () {
      final r = _r('بكرة الساعة 2 بالليل');
      expect(r.minutes, 120);
      expect(r.day, _d(18));
      expect(_r('الساعة 11 بالليل').minutes, 1380);
    });

    test('a bare 12 at night is the coming midnight', () {
      final r = _r('الساعة 12 بالليل');
      expect(r.minutes, 0);
      expect(r.day, _d(17));
    });
  });

  group('a time that has passed', () {
    final evening = DateTime(2026, 11, 16, 18, 0);

    test('a bare time rolls to tomorrow', () {
      final r = _r('الساعة 5 العصر', now: evening);
      expect(r.day, _d(17));
      expect(r.timePassed, isFalse);
    });

    test('an explicit today stays today and is flagged', () {
      final r = _r('اليوم الساعة 5 العصر', now: evening);
      expect(r.day, _d(16));
      expect(r.timePassed, isTrue);
    });

    test('a bare time still ahead stays today', () {
      final r = _r('الساعة 5 العصر');
      expect(r.day, _d(16));
      expect(r.timePassed, isFalse);
    });

    test('a weekday with a time is never flagged', () {
      final r = _r('الاثنين الساعة 8 الصبح', now: evening);
      expect(r.day, _d(23));
      expect(r.timePassed, isFalse);
    });
  });

  group('logical day cutoff', () {
    // 01:00 on the 16th still belongs to the logical 15th.
    final logicalToday = _d(15);
    final late = DateTime(2026, 11, 16, 1, 0);

    test('today and tomorrow follow the logical day', () {
      expect(_r('اليوم', today: logicalToday, now: late).day, _d(15));
      expect(_r('بكرة', today: logicalToday, now: late).day, _d(16));
    });

    test('a bare time that has passed on the wall clock rolls forward', () {
      final r = _r('الساعة 5 العصر', today: logicalToday, now: late);
      expect(r.day, _d(16));
    });
  });

  group('spans', () {
    test('cover the day word and the time phrase', () {
      final text = foldLetters('بكرة الساعة 10 الصبح');
      final m = findWhen(text);
      var rest = text;
      final sorted = [...m.spans]..sort((a, b) => b.$1.compareTo(a.$1));
      for (final (start, end) in sorted) {
        rest = rest.replaceRange(start, end, '');
      }
      expect(rest.trim(), isEmpty);
    });
  });
}
