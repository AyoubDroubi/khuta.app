import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/goals/data/goal_progress.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/substep.dart';
import 'package:khuta/features/habits/data/vacation.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/todos/data/todo.dart';

void main() {
  test('goal progress stays separate by source type and deduplicates ancestry', () {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final habit = Habit(
      id: 'habit-1',
      name: 'Read',
      color: Colors.blue,
      order: 0,
      perDayTarget: 2,
      createdAt: yesterday,
      completions: {
        today.dayKey: Completion(date: today.dayKey, count: 1),
      },
    );
    final todo = Todo(
      id: 'todo-1',
      text: 'Write a chapter',
      createdAt: yesterday,
      done: true,
      doneAt: today,
    );
    final journey = Journey(
      id: 'journey-1',
      title: 'Publish a book',
      status: JourneyStatus.active,
      milestones: const [
        JourneyMilestone(
          id: 'milestone-1',
          title: 'Outline',
          completed: true,
          order: 0,
        ),
        JourneyMilestone(
          id: 'milestone-2',
          title: 'Draft',
          completed: false,
          order: 1,
        ),
      ],
      createdAt: yesterday,
      updatedAt: today,
    );
    final root = Goal(
      id: 'root',
      title: 'Publish',
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: today,
        ),
        GoalSourceLink(
          type: GoalSourceType.todo,
          sourceId: todo.id,
          linkedAt: yesterday,
        ),
      ],
    );
    final child = Goal(
      id: 'child',
      title: 'Writing',
      parentGoalId: root.id,
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: yesterday,
        ),
        GoalSourceLink(
          type: GoalSourceType.journey,
          sourceId: journey.id,
          linkedAt: yesterday,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: root.id,
      goals: [root, child],
      habits: {habit.id: habit},
      todos: {todo.id: todo},
      journeys: {journey.id: journey},
      through: today,
      habitMaximumForDay: (_, _) => 2,
    );

    expect(progress.keys, {
      GoalSourceType.habit,
      GoalSourceType.todo,
      GoalSourceType.journey,
    });
    expect(progress[GoalSourceType.habit]!.percent, 25);
    expect(progress[GoalSourceType.habit]!.sourceCount, 1);
    expect(progress[GoalSourceType.todo]!.percent, 100);
    expect(progress[GoalSourceType.journey]!.percent, 50);
  });

  test('a parent includes linked sources at arbitrary descendant depth', () {
    final today = DateTime.now();
    final goals = <Goal>[];
    String? parent;
    for (var depth = 0; depth < 24; depth++) {
      final goal = Goal(
        id: 'goal-$depth',
        title: 'Goal $depth',
        parentGoalId: parent,
        createdAt: today,
        updatedAt: today,
        sources: depth == 23
            ? [
                GoalSourceLink(
                  type: GoalSourceType.todo,
                  sourceId: 'deep-todo',
                  linkedAt: today,
                ),
              ]
            : const [],
      );
      goals.add(goal);
      parent = goal.id;
    }

    final progress = GoalProgressCalculator.calculate(
      goalId: goals.first.id,
      goals: goals,
      habits: const {},
      todos: {
        'deep-todo': Todo(
          id: 'deep-todo',
          text: 'Finish',
          createdAt: today,
          done: true,
        ),
      },
      journeys: const {},
      through: today,
    );

    expect(progress[GoalSourceType.todo]!.percent, 100);
    expect(progress[GoalSourceType.todo]!.sourceCount, 1);
  });

  test('unavailable linked sources are excluded without a combined total', () {
    final today = DateTime.now();
    final goal = Goal(
      id: 'goal',
      title: 'Unavailable source',
      createdAt: today,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.todo,
          sourceId: 'missing',
          linkedAt: today,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: [goal],
      habits: const {},
      todos: const {},
      journeys: const {},
      through: today,
    );

    expect(progress, isEmpty);
  });
  test('negative habits count clean opportunities and exclude relapses', () {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final cleanHabit = Habit(
      id: 'clean',
      name: 'No smoking',
      color: Colors.green,
      order: 0,
      kind: HabitKind.negative,
      createdAt: yesterday,
    );
    final relapseHabit = Habit(
      id: 'relapse',
      name: 'No drinking',
      color: Colors.red,
      order: 1,
      kind: HabitKind.negative,
      createdAt: yesterday,
      completions: {
        today.dayKey: Completion(date: today.dayKey, count: 1),
      },
    );
    final goal = Goal(
      id: 'goal',
      title: 'Stay clean',
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        for (final habit in [cleanHabit, relapseHabit])
          GoalSourceLink(
            type: GoalSourceType.habit,
            sourceId: habit.id,
            linkedAt: today,
          ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: [goal],
      habits: {
        cleanHabit.id: cleanHabit,
        relapseHabit.id: relapseHabit,
      },
      todos: const {},
      journeys: const {},
      through: today,
    );

    expect(progress[GoalSourceType.habit]!.actual, 1);
    expect(progress[GoalSourceType.habit]!.target, 2);
    expect(progress[GoalSourceType.habit]!.percent, 50);
  });

  test('checklist progress counts completed substeps', () {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final habit = Habit(
      id: 'checklist',
      name: 'Morning routine',
      color: Colors.blue,
      order: 0,
      createdAt: yesterday,
      substeps: const [
        Substep(id: 'water', title: 'Drink water'),
        Substep(id: 'stretch', title: 'Stretch'),
        Substep(id: 'read', title: 'Read'),
      ],
      completions: {
        today.dayKey: Completion(
          date: today.dayKey,
          steps: {'water', 'stretch'},
        ),
      },
    );
    final goal = Goal(
      id: 'goal',
      title: 'Build a routine',
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: today,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: [goal],
      habits: {habit.id: habit},
      todos: const {},
      journeys: const {},
      through: today,
    );

    expect(progress[GoalSourceType.habit]!.actual, 2);
    expect(progress[GoalSourceType.habit]!.target, 3);
    expect(progress[GoalSourceType.habit]!.percent, closeTo(200 / 3, 0.001));
  });

  test('habit goal windows use the app day cutoff', () {
    final previousCutoff = AppClock.cutoffHour;
    AppClock.cutoffHour = 3;
    try {
      final logicalToday = AppClock.today();
      final previousDay = logicalToday.addDays(-1);
      final linkAtTwoAm = DateTime(
        logicalToday.year,
        logicalToday.month,
        logicalToday.day,
        2,
      );
      final habit = Habit(
        id: 'cutoff-habit',
        name: 'Read',
        color: Colors.blue,
        order: 0,
        perDayTarget: 2,
        createdAt: previousDay,
        completions: {
          previousDay.dayKey: Completion(
            date: previousDay.dayKey,
            count: 1,
          ),
          logicalToday.dayKey: Completion(
            date: logicalToday.dayKey,
            count: 1,
          ),
        },
      );
      final goal = Goal(
        id: 'goal',
        title: 'Read more',
        createdAt: previousDay,
        updatedAt: logicalToday,
        sources: [
          GoalSourceLink(
            type: GoalSourceType.habit,
            sourceId: habit.id,
            linkedAt: linkAtTwoAm,
          ),
        ],
      );

      final progress = GoalProgressCalculator.calculate(
        goalId: goal.id,
        goals: [goal],
        habits: {habit.id: habit},
        todos: const {},
        journeys: const {},
        through: logicalToday,
        habitMaximumForDay: (_, _) => 2,
      );

      expect(progress[GoalSourceType.habit]!.actual, 2);
      expect(progress[GoalSourceType.habit]!.target, 4);
      expect(progress[GoalSourceType.habit]!.percent, 50);
    } finally {
      AppClock.cutoffHour = previousCutoff;
    }
  });


  test('habit metric excludes unscheduled rest and vacation local days', () {
    final monday = DateTime(2026, 10, 5);
    final tuesday = monday.addDays(1);
    final wednesday = monday.addDays(2);
    final thursday = monday.addDays(3);
    final habit = Habit(
      id: 'schedule-pauses',
      name: 'Read',
      color: Colors.blue,
      order: 0,
      perDayTarget: 2,
      interval: HabitInterval.weekdays,
      scheduleWeekdays: [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
      ],
      restDays: [DateTime.tuesday],
      vacations: [
        VacationPeriod(start: wednesday, end: wednesday),
      ],
      createdAt: monday,
      completions: {
        monday.dayKey: Completion(date: monday.dayKey, count: 2),
        tuesday.dayKey: Completion(date: tuesday.dayKey, count: 2),
        wednesday.dayKey: Completion(date: wednesday.dayKey, count: 2),
        thursday.dayKey: Completion(date: thursday.dayKey, count: 1),
      },
      maximumTargetVersions: [
        HabitMaximumTargetVersion(
          effectiveDate: monday.dayKey,
          maximum: 2,
          recordedAt: monday,
        ),
      ],
    );
    final goal = Goal(
      id: 'schedule-goal',
      title: 'Respect schedule',
      createdAt: monday,
      updatedAt: thursday,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: monday,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: [goal],
      habits: {habit.id: habit},
      todos: const {},
      journeys: const {},
      through: thursday,
    );

    expect(progress[GoalSourceType.habit]!.actual, 3);
    expect(progress[GoalSourceType.habit]!.target, 4);
    expect(progress[GoalSourceType.habit]!.percent, 75);
  });

  test('habit progress resolves the effective maximum for every local day', () {
    final today = AppClock.today();
    final yesterday = today.addDays(-1);
    final habit = Habit(
      id: 'versioned-target',
      name: 'Read',
      color: Colors.blue,
      order: 0,
      perDayTarget: 99,
      createdAt: yesterday,
      completions: {
        yesterday.dayKey: Completion(date: yesterday.dayKey, count: 1),
        today.dayKey: Completion(date: today.dayKey, count: 4),
      },
    );
    final goal = Goal(
      id: 'goal',
      title: 'Read consistently',
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: yesterday,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: [goal],
      habits: {habit.id: habit},
      todos: const {},
      journeys: const {},
      through: today,
      habitMaximumForDay: (_, day) =>
          day.dayKey == yesterday.dayKey ? 2 : 4,
    );

    expect(progress[GoalSourceType.habit]!.actual, 5);
    expect(progress[GoalSourceType.habit]!.target, 6);
    expect(progress[GoalSourceType.habit]!.percent, closeTo(500 / 6, 0.001));
  });


  test('subtree dedupe uses the earliest link date for habit history', () {
    final today = AppClock.today();
    final yesterday = today.addDays(-1);
    final habit = Habit(
      id: 'shared-habit',
      name: 'Read',
      color: Colors.blue,
      order: 0,
      perDayTarget: 2,
      createdAt: yesterday,
      completions: {
        yesterday.dayKey: Completion(date: yesterday.dayKey, count: 1),
        today.dayKey: Completion(date: today.dayKey, count: 1),
      },
    );
    final root = Goal(
      id: 'root-earliest',
      title: 'Root',
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: today,
        ),
      ],
    );
    final child = Goal(
      id: 'child-earliest',
      title: 'Child',
      parentGoalId: root.id,
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: yesterday,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: root.id,
      goals: [root, child],
      habits: {habit.id: habit},
      todos: const {},
      journeys: const {},
      through: today,
      habitMaximumForDay: (_, _) => 2,
    );

    expect(progress[GoalSourceType.habit]!.actual, 2);
    expect(progress[GoalSourceType.habit]!.target, 4);
    expect(progress[GoalSourceType.habit]!.sourceCount, 1);
    expect(progress[GoalSourceType.habit]!.percent, 50);
  });

  test('habit history resolves different maxima for different local dates', () {
    final today = AppClock.today();
    final yesterday = today.addDays(-1);
    final habit = Habit(
      id: 'history-backed',
      name: 'Read',
      color: Colors.blue,
      order: 0,
      perDayTarget: 4,
      createdAt: yesterday,
      completions: {
        yesterday.dayKey: Completion(date: yesterday.dayKey, count: 2),
        today.dayKey: Completion(date: today.dayKey, count: 4),
      },
      maximumTargetVersions: [
        HabitMaximumTargetVersion(
          effectiveDate: yesterday.dayKey,
          maximum: 2,
          recordedAt: yesterday,
        ),
        HabitMaximumTargetVersion(
          effectiveDate: today.dayKey,
          maximum: 4,
          recordedAt: today,
        ),
      ],
    );
    final goal = Goal(
      id: 'goal-history-backed',
      title: 'Read consistently',
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: yesterday,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: [goal],
      habits: {habit.id: habit},
      todos: const {},
      journeys: const {},
      through: today,
    );

    expect(progress[GoalSourceType.habit]!.actual, 6);
    expect(progress[GoalSourceType.habit]!.target, 6);
    expect(progress[GoalSourceType.habit]!.percent, 100);
  });

  test('habit metric is hidden when a historical maximum cannot be resolved', () {
    final today = AppClock.today();
    final yesterday = today.addDays(-1);
    final habit = Habit(
      id: 'missing-history',
      name: 'Read',
      color: Colors.blue,
      order: 0,
      perDayTarget: 4,
      createdAt: yesterday,
      completions: {
        yesterday.dayKey: Completion(date: yesterday.dayKey, count: 1),
        today.dayKey: Completion(date: today.dayKey, count: 2),
      },
    );
    final goal = Goal(
      id: 'goal',
      title: 'Read consistently',
      createdAt: yesterday,
      updatedAt: today,
      sources: [
        GoalSourceLink(
          type: GoalSourceType.habit,
          sourceId: habit.id,
          linkedAt: yesterday,
        ),
      ],
    );

    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: [goal],
      habits: {habit.id: habit},
      todos: const {},
      journeys: const {},
      through: today,
      habitMaximumForDay: (_, day) =>
          day.dayKey == today.dayKey ? habit.effectiveTarget : null,
    );

    expect(progress.containsKey(GoalSourceType.habit), isFalse);
  });

}
