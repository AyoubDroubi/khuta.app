import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/goals/data/goal.dart';

// goals and their sources load from
// stored data in every shape the app has written, and refuse corrupt types.
void main() {
  group('GoalSourceLink', () {
    test('round-trips through its map', () {
      final link = GoalSourceLink(
        type: GoalSourceType.todo,
        sourceId: 't1',
        linkedAt: DateTime.utc(2026, 11, 8, 9),
        sourceTitle: 'Pay rent',
        available: false,
      );
      final again = GoalSourceLink.fromMap(link.toMap());
      expect(again.type, GoalSourceType.todo);
      expect(again.sourceId, 't1');
      expect(again.linkedAt, DateTime.utc(2026, 11, 8, 9));
      expect(again.sourceTitle, 'Pay rent');
      expect(again.available, isFalse);
    });

    test('the type may be a number, a name, or the older `type` key', () {
      expect(GoalSourceLink.fromMap({'sourceType': 2, 'sourceId': 'j'}).type, GoalSourceType.journey);
      expect(GoalSourceLink.fromMap({'sourceType': 'Habit', 'sourceId': 'h'}).type, GoalSourceType.habit);
      expect(GoalSourceLink.fromMap({'type': 'todo', 'sourceId': 't'}).type, GoalSourceType.todo);
    });

    test('an unknown type is refused, not coerced', () {
      expect(() => GoalSourceLink.fromMap({'sourceType': 'planet', 'sourceId': 'x'}), throwsFormatException);
      expect(() => GoalSourceLink.fromMap({'sourceType': 9, 'sourceId': 'x'}), throwsFormatException);
      expect(() => GoalSourceLink.fromMap({'sourceType': -1, 'sourceId': 'x'}), throwsFormatException);
    });

    test('missing fields get safe defaults and a link is available unless marked', () {
      final link = GoalSourceLink.fromMap({'sourceType': 0});
      expect(link.sourceId, '');
      expect(link.sourceTitle, '');
      expect(link.linkedAt.millisecondsSinceEpoch, 0);
      expect(link.available, isTrue);
    });
  });

  group('Goal', () {
    Goal sample() => Goal(
          id: 'g1',
          title: 'Run 5k',
          description: 'By spring',
          targetDate: '01-04-2027',
          state: GoalState.completed,
          parentGoalId: 'root',
          sources: [
            GoalSourceLink(
              type: GoalSourceType.habit,
              sourceId: 'h1',
              linkedAt: DateTime.utc(2026, 11, 1),
            ),
          ],
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 11, 2),
          version: 3,
        );

    test('round-trips through its map', () {
      final again = Goal.fromMap(sample().toMap());
      expect(again.id, 'g1');
      expect(again.title, 'Run 5k');
      expect(again.description, 'By spring');
      expect(again.targetDate, '01-04-2027');
      expect(again.state, GoalState.completed);
      expect(again.parentGoalId, 'root');
      expect(again.sources.single.sourceId, 'h1');
      expect(again.createdAt, DateTime.utc(2026, 10, 1));
      expect(again.updatedAt, DateTime.utc(2026, 11, 2));
      expect(again.version, 3);
    });

    test('the state may be a number or a name; unknown values become active', () {
      Goal withState(Object? s) => Goal.fromMap({'id': 'g', 'title': 't', 'status': s});
      expect(withState(1).state, GoalState.completed);
      expect(withState('Archived').state, GoalState.archived);
      expect(withState('active').state, GoalState.active);
      expect(withState('weird').state, GoalState.active);
      expect(withState(99).state, GoalState.archived); // clamped, not an error
      expect(withState(-5).state, GoalState.active);
    });

    test('an older map using `state` and `links` still loads', () {
      final goal = Goal.fromMap({
        'id': 'g',
        'title': 't',
        'state': 'completed',
        'links': [
          {'sourceType': 'journey', 'sourceId': 'j1'},
        ],
      });
      expect(goal.state, GoalState.completed);
      expect(goal.sources.single.type, GoalSourceType.journey);
    });

    test('an empty map loads as an empty active goal with epoch timestamps', () {
      final goal = Goal.fromMap(const {});
      expect(goal.id, '');
      expect(goal.state, GoalState.active);
      expect(goal.sources, isEmpty);
      expect(goal.createdAt.millisecondsSinceEpoch, 0);
    });
  });
}
