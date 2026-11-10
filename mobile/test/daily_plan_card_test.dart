import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/daily_plan/widgets/daily_plan_card.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();

  testWidgets('My Day shows three ordered priorities and its hard limit',
      (tester) async {
    final today = AppClock.today();
    final first = testHabit(
      id: 'habit-1',
      name: 'Morning walk',
      done: [today],
    );
    final second = testHabit(id: 'habit-2', name: 'Read');
    final third = testHabit(id: 'habit-3', name: 'Stretch');

    await tester.runAsync(() async {
      await LocalStore.writeHabit(first);
      await LocalStore.writeHabit(second);
      await LocalStore.writeHabit(third);
      await LocalStore.writeDailyPlan(
        DailyPlan(
          date: today.dayKey,
          items: const [
            DailyPlanItem(
              type: DailyPlanSourceType.habit,
              sourceId: 'habit-1',
            ),
            DailyPlanItem(
              type: DailyPlanSourceType.habit,
              sourceId: 'habit-2',
            ),
            DailyPlanItem(
              type: DailyPlanSourceType.habit,
              sourceId: 'habit-3',
            ),
          ],
        ),
      );
    });

    await pumpScreen(tester, const DailyPlanCard());

    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('1 of 3 priorities done'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit priorities'));
    await tester.pumpAndSettle();

    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('Up to 3 priorities'), findsOneWidget);
  });
}
