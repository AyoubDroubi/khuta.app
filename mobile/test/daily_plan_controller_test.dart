import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/daily_plan/state/daily_plan_controller.dart';

import 'support/app_harness.dart';

// the daily plan keeps at most three priorities, in
// order, without duplicates, and stores every change.
DailyPlanItem _habit(String id) =>
    DailyPlanItem(type: DailyPlanSourceType.habit, sourceId: id);

void main() {
  useEmptyStore();

  final day = AppClock.today();

  List<String> ids(DailyPlanController c, [DateTime? date]) =>
      c.forDate(date ?? day).items.map((i) => i.sourceId).toList();

  test('an empty day has an empty plan', () {
    final c = DailyPlanController();
    expect(c.forDate(day).items, isEmpty);
    expect(c.today.date, day.dayKey);
  });

  test('items are added in order and stored', () async {
    final c = DailyPlanController();
    await c.add(day, _habit('a'));
    await c.add(day, _habit('b'));
    expect(ids(c), ['a', 'b']);
    expect(ids(DailyPlanController()), ['a', 'b']);
    expect(c.forDate(day).updatedAt, isNotNull);
  });

  test('a fourth priority is refused', () async {
    final c = DailyPlanController();
    for (final id in ['a', 'b', 'c', 'd']) {
      await c.add(day, _habit(id));
    }
    expect(ids(c), ['a', 'b', 'c']);
    expect(DailyPlan.maxItems, 3);
  });

  test('the same source cannot be added twice, but a milestone of it can', () async {
    final c = DailyPlanController();
    await c.add(day, _habit('a'));
    await c.add(day, _habit('a'));
    expect(ids(c), ['a']);
    await c.add(
      day,
      const DailyPlanItem(
        type: DailyPlanSourceType.journeyMilestone,
        sourceId: 'j',
        milestoneId: 'm1',
      ),
    );
    await c.add(
      day,
      const DailyPlanItem(
        type: DailyPlanSourceType.journeyMilestone,
        sourceId: 'j',
        milestoneId: 'm2',
      ),
    );
    expect(c.forDate(day).items, hasLength(3));
  });

  test('remove drops one item and keeps the order of the rest', () async {
    final c = DailyPlanController();
    for (final id in ['a', 'b', 'c']) {
      await c.add(day, _habit(id));
    }
    await c.remove(day, _habit('b').key);
    expect(ids(c), ['a', 'c']);
    expect(ids(DailyPlanController()), ['a', 'c']);
    await c.remove(day, 'habit:missing:');
    expect(ids(c), ['a', 'c']);
  });

  test('move swaps positions and ignores impossible moves', () async {
    final c = DailyPlanController();
    for (final id in ['a', 'b', 'c']) {
      await c.add(day, _habit(id));
    }
    await c.move(day, 0, 2);
    expect(ids(c), ['b', 'c', 'a']);
    await c.move(day, 1, 1);
    await c.move(day, -1, 0);
    await c.move(day, 0, 3);
    await c.move(day, 5, 0);
    expect(ids(c), ['b', 'c', 'a']);
    expect(ids(DailyPlanController()), ['b', 'c', 'a']);
  });

  test('reorder follows the list convention (moving down counts the gap)', () async {
    final c = DailyPlanController();
    for (final id in ['a', 'b', 'c']) {
      await c.add(day, _habit(id));
    }
    await c.reorder(day, 0, 3); // a to the end
    expect(ids(c), ['b', 'c', 'a']);
    await c.reorder(day, 2, 0); // a back to the front
    expect(ids(c), ['a', 'b', 'c']);
    await c.reorder(day, 3, 0);
    await c.reorder(day, 0, 4);
    await c.reorder(day, -1, 1);
    expect(ids(c), ['a', 'b', 'c']);
  });

  test('plans of different days are independent', () async {
    final c = DailyPlanController();
    final tomorrow = day.addDays(1);
    await c.add(day, _habit('a'));
    await c.add(tomorrow, _habit('b'));
    expect(ids(c), ['a']);
    expect(ids(c, tomorrow), ['b']);
    final again = DailyPlanController();
    expect(ids(again, tomorrow), ['b']);
  });

  test('reload picks up what another controller stored', () async {
    final a = DailyPlanController();
    final b = DailyPlanController();
    await a.add(day, _habit('x'));
    expect(ids(b), isEmpty);
    b.reload();
    expect(ids(b), ['x']);
  });
}
