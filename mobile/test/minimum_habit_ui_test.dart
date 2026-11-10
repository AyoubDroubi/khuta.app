import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/pages/habit_form_page.dart';
import 'package:khuta/features/habits/widgets/target_history.dart';

import 'support/app_harness.dart';

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
  final today = AppClock.today();

  Habit withMinimum() => testHabit(
        id: 'q',
        name: 'Water',
        kind: HabitKind.quantitative,
        perDayTarget: 10,
        unitLabel: 'glasses',
      ).copyWith(
        minimumTargetVersions: [
          HabitMinimumTargetVersion(
            effectiveDate: today.addDays(-2).dayKey,
            minimum: 4,
            recordedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
        completions: {
          today.dayKey: Completion(date: today.dayKey, count: 4, hour: 9),
        },
      );

  test('target changes are listed newest first, empty without a minimum', () {
    expect(targetChanges(withMinimum()).single.amount, 4);
    expect(
        targetChanges(testHabit(
            id: 'x', name: 'x', kind: HabitKind.quantitative, perDayTarget: 3)),
        isEmpty);
  });

  for (final style in {0: 'classic', 1: 'minimal', 2: 'express'}.entries) {
    testWidgets('${style.value}: details show the minimum and its history',
        (tester) async {
      await seedHabits(tester, [withMinimum()]);
      await pumpScreen(tester, const HabitDetailsPage(habitId: 'q'),
          settings: {'appStyle': style.key});
      expect(find.textContaining('min 4'), findsWidgets);
      expect(find.textContaining('6 left'), findsWidgets);
      await _reveal(tester, find.text('Target history'));
      await tester.tap(find.text('Target history'));
      await tester.pumpAndSettle();
      expect(find.text('Minimum 4'), findsWidgets);
    });

    for (final locale in ['en', 'ar']) {
      testWidgets('${style.value} $locale: editor minimum field, large text',
          (tester) async {
        await seedHabits(tester, [withMinimum()]);
        await pumpScreen(
          tester,
          HabitFormPage(habit: withMinimum()),
          settings: {'appStyle': style.key},
          locale: Locale(locale),
          textScale: 2,
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 500));
        final label = locale == 'ar' ? 'الحد الأدنى المحسوب' : 'Minimum that counts';
        await _reveal(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
