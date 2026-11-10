import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';

void main() {
  test('daily plan round-trips ordered source references', () {
    const plan = DailyPlan(
      date: '25-09-2026',
      version: 4,
      items: [
        DailyPlanItem(
          type: DailyPlanSourceType.habit,
          sourceId: '11111111-1111-1111-1111-111111111111',
        ),
        DailyPlanItem(
          type: DailyPlanSourceType.journeyMilestone,
          sourceId: '22222222-2222-2222-2222-222222222222',
          milestoneId: '33333333-3333-3333-3333-333333333333',
        ),
      ],
    );

    final copy = DailyPlan.fromMap(plan.toMap());

    expect(copy.date, '25-09-2026');
    expect(copy.version, 4);
    expect(copy.items, hasLength(2));
    expect(copy.items.first.type, DailyPlanSourceType.habit);
    expect(copy.items.last.type, DailyPlanSourceType.journeyMilestone);
    expect(
      copy.items.last.milestoneId,
      '33333333-3333-3333-3333-333333333333',
    );
  });

  test('daily plan exposes a three-priority product limit', () {
    expect(DailyPlan.maxItems, 3);
  });

  test('daily plan rejects corrupt source shapes instead of coercing them', () {
    expect(
      () => DailyPlanItem.fromMap({
        'type': 99,
        'sourceId': 'source',
      }),
      throwsFormatException,
    );
    expect(
      () => DailyPlanItem.fromMap({
        'type': DailyPlanSourceType.journeyMilestone.index,
        'sourceId': 'journey',
      }),
      throwsFormatException,
    );
    expect(
      () => DailyPlan.fromMap({
        'date': '25-09-2026',
        'items': List.generate(
          4,
          (index) => {
            'type': DailyPlanSourceType.habit.index,
            'sourceId': 'habit-$index',
          },
        ),
      }),
      throwsFormatException,
    );
  });
}
