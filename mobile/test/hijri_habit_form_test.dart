import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/pages/habit_form_page.dart';
import 'package:khuta/features/habits/widgets/habit_form_schedule.dart';
import 'package:khuta/features/habits/widgets/hijri_schedule_selector.dart';

import 'support/app_harness.dart';

// the habit editor offers
// Gregorian or Hijri; Hijri shows the 12 month chips and hides the interval
// options, in all three styles, in English (LTR) and Arabic (RTL).
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  useEmptyStore();

  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};
  const labels = {
    'en': (hijri: 'Hijri', ramadan: 'Ramadan', daily: 'Daily'),
    'ar': (hijri: 'هجري', ramadan: 'رمضان', daily: 'يوميًا'),
  };

  for (final locale in labels.keys) {
    for (final style in styles.entries) {
      testWidgets('$locale ${style.value}: Hijri months replace the interval options',
          (tester) async {
        await pumpScreen(
          tester,
          const HabitFormPage(),
          settings: {'appStyle': style.key},
          locale: Locale(locale),
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 500));
        final l = labels[locale]!;

        await _reveal(tester, find.text(l.hijri));
        expect(find.byType(HijriScheduleSelector), findsOneWidget);
        expect(find.text(l.daily), findsOneWidget); // interval options
        expect(find.text(l.ramadan), findsNothing);

        await tester.tap(find.text(l.hijri));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(l.daily), findsNothing);
        expect(find.byType(IntervalSelector), findsNothing);
        expect(find.text(l.ramadan), findsOneWidget);
        for (final widget in tester.widgetList<Directionality>(find.byType(Directionality))) {
          if (widget.textDirection == (locale == 'ar' ? TextDirection.rtl : TextDirection.ltr)) {
            return expect(tester.takeException(), isNull);
          }
        }
        fail('expected ${locale == 'ar' ? 'RTL' : 'LTR'} layout');
      });
    }
  }

  testWidgets('saving a Hijri habit stores daily + chosen months', (tester) async {
    await pumpScreen(tester, const HabitFormPage(), locale: const Locale('en'), settle: false);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, 'Fast');
    await _reveal(tester, find.text('Hijri'));
    await tester.tap(find.text('Hijri'));
    await tester.pump(const Duration(milliseconds: 300));
    await _reveal(tester, find.text('Shaban'));
    await tester.tap(find.text('Shaban')); // Ramadan is pre-selected
    await tester.pump(const Duration(milliseconds: 300));

    await _reveal(tester, find.text('Save'));
    await tester.tap(find.text('Save').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));

    final saved = await tester.runAsync(() async => LocalStore.readHabits().values.toList());
    expect(saved, hasLength(1));
    final habit = saved!.single;
    expect(habit.scheduleCalendar, ScheduleCalendar.hijri);
    expect(habit.hijriMonths, [8, 9]);
    expect(habit.interval, HabitInterval.daily);
    // Let the debounced home-widget refresh (700 ms) fire.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no months chosen → cannot save', (tester) async {
    await pumpScreen(tester, const HabitFormPage(), locale: const Locale('en'), settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, 'Fast');
    await _reveal(tester, find.text('Hijri'));
    await tester.tap(find.text('Hijri'));
    await tester.pump(const Duration(milliseconds: 300));
    await _reveal(tester, find.text('Ramadan'));
    await tester.tap(find.text('Ramadan')); // deselect the only month
    await tester.pump(const Duration(milliseconds: 300));
    await _reveal(tester, find.text('Save'));
    await tester.tap(find.text('Save').first);
    await tester.pump(const Duration(milliseconds: 500));
    final saved = await tester.runAsync(() async => LocalStore.readHabits());
    expect(saved, isEmpty);
  });

  for (final c in const [('en', 'Every day in Shaban, Ramadan'), ('ar', 'كل يوم في شعبان، رمضان')]) {
    testWidgets('${c.$1}: details page shows the Hijri schedule', (tester) async {
      await seedHabits(tester, [
        testHabit(id: 'f', name: 'Fast', order: 0).copyWith(
          scheduleCalendar: ScheduleCalendar.hijri,
          hijriMonths: const [9, 8],
        ),
      ]);
      await pumpScreen(tester, const HabitDetailsPage(habitId: 'f'), locale: Locale(c.$1), settle: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(c.$2), findsWidgets);
    });
  }
}
