import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/goals/pages/goal_detail_page.dart';
import 'package:khuta/features/goals/pages/goals_page.dart';

import 'support/app_harness.dart';

Goal _goal(
  String id, {
  required String title,
  GoalState state = GoalState.active,
}) {
  final now = DateTime.utc(2026, 10, 6);
  return Goal(
    id: id,
    title: title,
    state: state,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  useEmptyStore();

  testWidgets('archived goals remain visible and can be opened for restore', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await LocalStore.writeGoal(
        _goal(
          'archived-goal',
          title: 'Archived outcome',
          state: GoalState.archived,
        ),
      );
    });

    await pumpScreen(tester, const GoalsPage());

    expect(find.text('Archived outcome'), findsOneWidget);
    expect(find.text('Archived'), findsWidgets);

    await tester.tap(find.text('Archived outcome'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalDetailPage), findsOneWidget);
    expect(find.text('Restore goal'), findsOneWidget);
  });

  testWidgets('a leaf goal can be deleted from its detail page', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await LocalStore.writeGoal(
        _goal('leaf-goal', title: 'Temporary outcome'),
      );
    });

    await pumpScreen(
      tester,
      const GoalDetailPage(goalId: 'leaf-goal'),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Temporary outcome'), findsWidgets);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(LocalStore.readGoals(), isEmpty);
  });
}
