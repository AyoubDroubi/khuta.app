import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/app/home_shell.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/calendar/calendar_display.dart';

import 'support/app_harness.dart';

// Umm al-Qura reference dates.
void main() {
  useEmptyStore();

  // Gregorian date → Umm al-Qura (year, month, day).
  final reference = <DateTime, HijriDay>{
    DateTime(2022, 4, 2): const HijriDay(1443, 9, 1), // 1 Ramadan 1443
    DateTime(2022, 5, 2): const HijriDay(1443, 10, 1), // 1 Shawwal 1443
    DateTime(2022, 7, 30): const HijriDay(1444, 1, 1), // 1 Muharram 1444
    DateTime(2023, 3, 23): const HijriDay(1444, 9, 1), // 1 Ramadan 1444
    DateTime(2023, 4, 21): const HijriDay(1444, 10, 1), // 1 Shawwal 1444
    DateTime(2023, 6, 28): const HijriDay(1444, 12, 10), // 10 Dhu al-Hijjah
    DateTime(2023, 7, 19): const HijriDay(1445, 1, 1), // 1 Muharram 1445
    DateTime(2024, 3, 11): const HijriDay(1445, 9, 1), // 1 Ramadan 1445
    DateTime(2024, 4, 10): const HijriDay(1445, 10, 1), // 1 Shawwal 1445
    DateTime(2024, 6, 16): const HijriDay(1445, 12, 10), // 10 Dhu al-Hijjah
    DateTime(2024, 7, 7): const HijriDay(1446, 1, 1), // 1 Muharram 1446
    DateTime(2025, 3, 1): const HijriDay(1446, 9, 1), // 1 Ramadan 1446
    DateTime(2025, 3, 30): const HijriDay(1446, 10, 1), // 1 Shawwal 1446
    DateTime(2025, 6, 6): const HijriDay(1446, 12, 10), // 10 Dhu al-Hijjah
    DateTime(2025, 6, 26): const HijriDay(1447, 1, 1), // 1 Muharram 1447
    DateTime(2026, 2, 18): const HijriDay(1447, 9, 1), // 1 Ramadan 1447
    DateTime(2026, 3, 20): const HijriDay(1447, 10, 1), // 1 Shawwal 1447
    DateTime(2026, 5, 26): const HijriDay(1447, 12, 9), // Arafah 1447
    DateTime(2026, 5, 27): const HijriDay(1447, 12, 10), // 10 Dhu al-Hijjah
    DateTime(2026, 6, 16): const HijriDay(1448, 1, 1), // 1 Muharram 1448
  };

  test('Umm al-Qura conversion matches the reference dates', () {
    final wrong = <String>[];
    reference.forEach((g, h) {
      final got = hijriOf(g);
      if (got != h) wrong.add('$g → $got (expected $h)');
    });
    expect(wrong, isEmpty);
  });

  test('the adjustment shifts by whole days within −2…+2', () {
    final base = DateTime(2026, 3, 20); // 1 Shawwal 1447
    expect(hijriOf(base, adjust: -1), const HijriDay(1447, 9, 30));
    expect(hijriOf(base, adjust: 1), const HijriDay(1447, 10, 2));
    expect(hijriOf(base, adjust: 5), hijriOf(base, adjust: 2));
    expect(hijriOf(base, adjust: -5), hijriOf(base, adjust: -2));
  });

  test('dates outside the table fall back to Gregorian', () {
    expect(hijriOf(DateTime(1900)), isNull);
    expect(hijriOf(DateTime(2100)), isNull);
    expect(
      dayLabel(
        DateTime(2100),
        gregorian: 'G',
        locale: 'ar',
        mode: CalendarMode.hijri,
      ),
      'G',
    );
  });

  test('the four display modes', () {
    final day = DateTime(2026, 2, 18);
    String label(CalendarMode m) =>
        dayLabel(day, gregorian: 'G', locale: 'ar', mode: m);
    expect(label(CalendarMode.gregorian), 'G');
    expect(label(CalendarMode.hijri), '1 رمضان 1447 هـ');
    expect(label(CalendarMode.gregorianHijri), 'G · 1 رمضان 1447 هـ');
    expect(label(CalendarMode.hijriGregorian), '1 رمضان 1447 هـ · G');
    expect(
      dayLabel(day, gregorian: 'G', locale: 'en', mode: CalendarMode.hijri),
      '1 Ramadan 1447 AH',
    );
  });

  for (final style in const [0, 1, 2]) {
    testWidgets('style $style: the Today header follows the calendar mode',
        (tester) async {
      await seedHabits(tester, [testHabit(id: 'a', name: 'Read')]);
      await pumpScreen(
        tester,
        const HomeShell(),
        settings: {'appStyle': style, 'calendarMode': 2, 'hijriAdjust': 1},
        locale: const Locale('ar'),
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      final hijri = formatHijri(
        hijriOf(AppClock.now(), adjust: 1)!,
        'ar',
        withYear: false,
      );
      if (style == 1) {
        // Minimal has no date header on Today.
        expect(find.textContaining(hijri), findsNothing);
      } else {
        expect(find.textContaining(hijri), findsOneWidget);
      }
    });
  }
}
