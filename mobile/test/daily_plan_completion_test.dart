import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/daily_plan/data/daily_plan_completion.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/todos/data/todo.dart';

void main() {
  test('negative habit is not completed before the current day ends', () {
    final today = AppClock.today();
    final habit = Habit(
      id: 'habit-negative',
      name: 'No smoking',
      color: const Color(0xFF000000),
      order: 0,
      kind: HabitKind.negative,
      createdAt: today.subtract(const Duration(days: 5)),
    );

    expect(DailyPlanCompletion.habitCompletedOn(habit, today), isFalse);
    expect(
      DailyPlanCompletion.habitCompletedOn(
        habit,
        today.subtract(const Duration(days: 1)),
      ),
      isTrue,
    );
  });

  test('todo completion belongs to the day it was completed', () {
    final todo = Todo(
      id: 'todo-1',
      text: 'Ship',
      createdAt: DateTime(2026, 9, 25, 9),
      done: true,
      doneAt: DateTime(2026, 9, 25, 18),
    );

    expect(
      DailyPlanCompletion.todoCompletedOn(todo, DateTime(2026, 9, 25)),
      isTrue,
    );
    expect(
      DailyPlanCompletion.todoCompletedOn(todo, DateTime(2026, 9, 24)),
      isFalse,
    );
  });

  test('milestone completion belongs to its completion day', () {
    final milestone = JourneyMilestone(
      id: 'm-1',
      title: 'Prototype',
      completed: true,
      order: 0,
      completedAt: DateTime(2026, 9, 25, 19),
    );

    expect(
      DailyPlanCompletion.milestoneCompletedOn(
        milestone,
        DateTime(2026, 9, 25),
      ),
      isTrue,
    );
    expect(
      DailyPlanCompletion.milestoneCompletedOn(
        milestone,
        DateTime(2026, 9, 26),
      ),
      isFalse,
    );
  });

  test('daily plan outcome derives completed and planned counts', () {
    final day = DateTime(2026, 9, 25);
    final habit = Habit(
      id: 'habit-1',
      name: 'Read',
      color: const Color(0xFF000000),
      order: 0,
      createdAt: day.subtract(const Duration(days: 3)),
      completions: {
        '25-09-2026': Completion(
          date: '25-09-2026',
          hour: 9,
          count: 1,
        ),
      },
    );
    final todo = Todo(
      id: 'todo-1',
      text: 'Ship',
      createdAt: day.subtract(const Duration(hours: 3)),
      done: false,
    );
    final plan = DailyPlan(
      date: '25-09-2026',
      items: const [
        DailyPlanItem(
          type: DailyPlanSourceType.habit,
          sourceId: 'habit-1',
        ),
        DailyPlanItem(
          type: DailyPlanSourceType.todo,
          sourceId: 'todo-1',
        ),
      ],
    );

    final outcome = DailyPlanCompletion.outcomeFor(
      plan,
      day,
      habits: [habit],
      todos: [todo],
      journeys: const [],
    );

    expect(outcome.plannedCount, 2);
    expect(outcome.completedCount, 1);
    expect(outcome.progress, 0.5);
  });
}
