import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/habit_form_page.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/features/recovery/data/recovery_config.dart';
import 'package:khuta/features/recovery/data/recovery_plan.dart';
import 'package:khuta/features/recovery/widgets/recovery_section.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

import 'support/app_harness.dart';

/// A very tall window builds the whole form, so no scrolling is needed.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  tester.view.physicalSize = const Size(1080, 14000);
  await tester.pump(const Duration(milliseconds: 300));
  expect(finder, findsWidgets);
}

void main() {
  useEmptyStore();
  final today = AppClock.today();

  Habit lapsed({bool enabled = true}) => testHabit(id: 'r', name: 'Read')
      .copyWith(
        createdAt: today.addDays(-10),
        recovery: RecoveryConfig(enabled: enabled),
        completions: {
          today.addDays(-5).dayKey: Completion(
              date: today.addDays(-5).dayKey, count: 1, hour: 8, minute: 0),
        },
      );

  test('the shared threshold defaults to 24 h, persists and is clamped', () async {
    final settings = SettingsController();
    expect(settings.recoveryThresholdHours, 24);
    await settings.setRecoveryThresholdHours(29);
    expect(SettingsController().recoveryThresholdHours, 29);
    await settings.setRecoveryThresholdHours(0);
    expect(settings.recoveryThresholdHours, 1);
    await settings.setRecoveryThresholdHours(100000);
    expect(settings.recoveryThresholdHours, RecoveryPlan.maxThresholdHours);
  });

  test('reaching the minimum counts as activity and resets Recovery', () {
    final h = testHabit(
      id: 'q',
      name: 'Water',
      kind: HabitKind.quantitative,
      perDayTarget: 10,
    ).copyWith(
      createdAt: today.addDays(-10),
      recovery: const RecoveryConfig(enabled: true),
      minimumTargetVersions: [
        HabitMinimumTargetVersion(
          effectiveDate: today.addDays(-9).dayKey,
          minimum: 3,
          recordedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      completions: {
        today.dayKey: Completion(date: today.dayKey, count: 3, hour: 7),
      },
    );
    final now = DateTime(today.year, today.month, today.day, 23);
    expect(RecoveryPlan.isEligible(h, now, 24), isFalse);
    final below = h.copyWith(completions: {
      today.dayKey: Completion(date: today.dayKey, count: 2, hour: 7),
    });
    expect(RecoveryPlan.isEligible(below, now, 24), isTrue);
  });

  for (final style in {0: 'classic', 1: 'minimal', 2: 'express'}.entries) {
    for (final locale in ['en', 'ar']) {
      testWidgets('${style.value} $locale: Today lists lapsed habits and dismisses',
          (tester) async {
        await seedHabits(tester, [lapsed()]);
        await pumpScreen(tester, const HomePage(),
            settings: {'appStyle': style.key},
            locale: Locale(locale),
            settle: false);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(RecoverySection), findsOneWidget);
        final title = locale == 'ar' ? 'التعافي' : 'Recovery';
        expect(find.text(title), findsOneWidget);
        final dismiss = locale == 'ar' ? 'إخفاء' : 'Dismiss';
        await tester.tap(find.byTooltip(dismiss));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(title), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final style in {0: 'classic', 1: 'minimal', 2: 'express'}.entries) {
    for (final locale in ['en', 'ar']) {
      testWidgets('${style.value} $locale: Today section at 2x text has no overflow',
          (tester) async {
        await seedHabits(tester, [lapsed()]);
        await pumpScreen(tester, const HomePage(),
            settings: {'appStyle': style.key},
            locale: Locale(locale),
            textScale: 2,
            settle: false);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(RecoverySection), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a habit with Recovery off is not listed', (tester) async {
    await seedHabits(tester, [lapsed(enabled: false)]);
    await pumpScreen(tester, const HomePage());
    expect(find.text('Recovery'), findsNothing);
  });

  for (final style in {0: 'classic', 1: 'minimal', 2: 'express'}.entries) {
    testWidgets('${style.value}: editor offers Recovery with large text',
        (tester) async {
      await seedHabits(tester, [lapsed()]);
      await pumpScreen(
        tester,
        HabitFormPage(habit: lapsed()),
        settings: {'appStyle': style.key},
        textScale: 2,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await _reveal(tester, find.text('Recovery reminders'));
      expect(find.text('Recovery reminders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${style.value}: settings show the shared threshold',
        (tester) async {
      await pumpScreen(tester, const SettingsPage(),
          settings: {'appStyle': style.key}, settle: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Preferences'));
      await tester.pump(const Duration(seconds: 1));
      await _reveal(tester, find.text('Recovery after a break'));
      expect(find.text('Recovery after a break'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
