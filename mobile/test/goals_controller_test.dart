import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/goals/data/goal_repository.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';

class _FakeGoalRepository extends GoalRepository {
  _FakeGoalRepository([Iterable<Goal> seed = const []])
      : items = {for (final goal in seed) goal.id: goal};

  final Map<String, Goal> items;

  @override
  List<Goal> readAll() => items.values.toList();

  @override
  Future<void> save(Goal goal) async {
    items[goal.id] = goal;
  }

  @override
  Future<void> remove(String id) async {
    items.remove(id);
  }
}

Goal _goal(
  String id, {
  String? parentGoalId,
  GoalState state = GoalState.active,
}) {
  final now = DateTime.utc(2026, 10, 5);
  return Goal(
    id: id,
    title: 'Goal $id',
    parentGoalId: parentGoalId,
    state: state,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('supports arbitrary-depth hierarchy without a product depth cap', () async {
    final repository = _FakeGoalRepository([_goal('root')]);
    final controller = GoalsController(repository: repository);

    var parent = 'root';
    for (var depth = 0; depth < 32; depth++) {
      final child = await controller.create(
        title: 'Depth $depth',
        parentGoalId: parent,
      );
      parent = child.id;
    }

    expect(controller.all, hasLength(33));
    expect(controller.childrenOf('root'), hasLength(1));
  });

  test('rejects indirect hierarchy cycles', () async {
    final repository = _FakeGoalRepository([
      _goal('root'),
      _goal('child', parentGoalId: 'root'),
      _goal('grandchild', parentGoalId: 'child'),
    ]);
    final controller = GoalsController(repository: repository);

    final root = controller.byId('root')!;
    expect(controller.canUseParent('root', 'grandchild'), isFalse);
    expect(
      () => controller.save(root.copyWith(parentGoalId: 'grandchild')),
      throwsArgumentError,
    );
  });

  test('source links are deduplicated on create', () async {
    final repository = _FakeGoalRepository();
    final controller = GoalsController(repository: repository);
    final now = DateTime.utc(2026, 10, 5);

    final goal = await controller.create(
      title: 'Ship',
      sources: [
        GoalSourceLink(
          type: GoalSourceType.todo,
          sourceId: 'todo-1',
          linkedAt: now,
        ),
        GoalSourceLink(
          type: GoalSourceType.todo,
          sourceId: 'todo-1',
          linkedAt: now,
        ),
      ],
    );

    expect(goal.sources, hasLength(1));
  });

  test('cannot delete a goal while it has active subgoals', () async {
    final repository = _FakeGoalRepository([
      _goal('root'),
      _goal('child', parentGoalId: 'root'),
    ]);
    final controller = GoalsController(repository: repository);

    expect(() => controller.remove('root'), throwsStateError);
    expect(repository.items.containsKey('root'), isTrue);
  });


  test('archived subgoals still block deleting their parent', () async {
    final repository = _FakeGoalRepository([
      _goal('root'),
      _goal(
        'archived-child',
        parentGoalId: 'root',
        state: GoalState.archived,
      ),
    ]);
    final controller = GoalsController(repository: repository);

    expect(() => controller.remove('root'), throwsStateError);
    expect(repository.items.containsKey('root'), isTrue);
  });

  test('archive and restore preserve goal identity', () async {
    final repository = _FakeGoalRepository([_goal('root')]);
    final controller = GoalsController(repository: repository);

    await controller.setState('root', GoalState.archived);
    expect(controller.byId('root')!.state, GoalState.archived);

    await controller.setState('root', GoalState.active);
    expect(controller.byId('root')!.state, GoalState.active);
    expect(controller.byId('root')!.id, 'root');
  });

  test('archived goals remain discoverable so they can be restored', () {
    final repository = _FakeGoalRepository([
      _goal('active'),
      _goal('archived', state: GoalState.archived),
    ]);
    final controller = GoalsController(repository: repository);

    expect(controller.roots.map((goal) => goal.id), contains('active'));
    expect(controller.roots.map((goal) => goal.id), isNot(contains('archived')));
    expect(controller.archived.map((goal) => goal.id), ['archived']);
  });

}
