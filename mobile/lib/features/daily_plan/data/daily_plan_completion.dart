import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/daily_plan/data/daily_plan_outcome.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/todos/data/todo.dart';

class DailyPlanCompletion {
  const DailyPlanCompletion._();

  static bool habitCompletedOn(Habit habit, DateTime day) {
    final today = AppClock.today();
    if (habit.kind == HabitKind.negative) {
      return day.atMidnight.isBefore(today) && habit.isCompletedOn(day);
    }
    return habit.isCompletedOn(day) || habit.isCoveredOn(day);
  }

  static bool todoCompletedOn(Todo todo, DateTime day) {
    if (!todo.done) return false;
    final completedAt = todo.doneAt;
    if (completedAt == null) {
      return day.isSameDay(AppClock.today());
    }
    return completedAt.toLocal().isSameDay(day);
  }

  static bool? itemCompletedOn(
    DailyPlanItem item,
    DateTime day, {
    required Iterable<Habit> habits,
    required Iterable<Todo> todos,
    required Iterable<Journey> journeys,
  }) {
    switch (item.type) {
      case DailyPlanSourceType.habit:
        for (final habit in habits) {
          if (habit.id == item.sourceId) {
            return habitCompletedOn(habit, day);
          }
        }
        return null;
      case DailyPlanSourceType.todo:
        for (final todo in todos) {
          if (todo.id == item.sourceId) {
            return todoCompletedOn(todo, day);
          }
        }
        return null;
      case DailyPlanSourceType.journeyMilestone:
        for (final journey in journeys) {
          if (journey.id != item.sourceId) continue;
          for (final milestone in journey.milestones) {
            if (milestone.id == item.milestoneId) {
              return milestoneCompletedOn(milestone, day);
            }
          }
        }
        return null;
    }
  }

  static DailyPlanOutcome outcomeFor(
    DailyPlan plan,
    DateTime day, {
    required Iterable<Habit> habits,
    required Iterable<Todo> todos,
    required Iterable<Journey> journeys,
  }) =>
      DailyPlanOutcome.fromCompletionStates(
        plan,
        plan.items.map(
          (item) =>
              itemCompletedOn(
                item,
                day,
                habits: habits,
                todos: todos,
                journeys: journeys,
              ) ??
              false,
        ),
      );

  static bool milestoneCompletedOn(
    JourneyMilestone milestone,
    DateTime day,
  ) {
    if (!milestone.completed) return false;
    final completedAt = milestone.completedAt;
    if (completedAt == null) {
      return day.isSameDay(AppClock.today());
    }
    return completedAt.toLocal().isSameDay(day);
  }
}
