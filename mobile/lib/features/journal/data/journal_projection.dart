import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

class JournalProjection {
  const JournalProjection._();

  static Set<String> daysWithActivity({
    required HabitsController habits,
    required FocusController focus,
    required TodosController todos,
  }) {
    final result = <String>{};

    for (final habit in habits.all) {
      result.addAll(habit.completions.keys);
    }
    for (final session in focus.sessions) {
      result.add(session.startedAt.toLocal().dayKey);
    }
    for (final todo in todos.all) {
      final completedAt = todo.doneAt;
      if (todo.done && completedAt != null) {
        result.add(completedAt.toLocal().dayKey);
      }
    }

    return result;
  }

  static List<JournalActivity> forDay({
    required DateTime day,
    required HabitsController habits,
    required FocusController focus,
    required TodosController todos,
  }) {
    final dayKey = day.dayKey;
    final result = <JournalActivity>[];

    for (final habit in habits.all) {
      final completion = habit.completions[dayKey];
      if (completion != null) {
        result.add(
          JournalActivity(
            id: 'completion:${habit.id}:$dayKey',
            type: 'habit_completion',
            date: dayKey,
            occurredAt: completion.stamp ??
                day.atMidnight.add(const Duration(hours: 23)),
            habitId: habit.id,
            habitName: habit.name,
            amount: completion.count,
          ),
        );
      }
    }

    for (final session in focus.sessions.where((item) => item.startedAt.dayKey == dayKey)) {
      final habit = habits.byId(session.habitId);
      result.add(
        JournalActivity(
          id: 'focus:${session.id}',
          type: 'focus',
          date: dayKey,
          occurredAt: session.startedAt,
          habitId: session.habitId,
          habitName: habit?.name ?? '',
          seconds: session.seconds,
        ),
      );
    }

    for (final todo in todos.all) {
      final completedAt = todo.doneAt;
      if (!todo.done ||
          completedAt == null ||
          completedAt.toLocal().dayKey != dayKey) {
        continue;
      }

      result.add(
        JournalActivity(
          id: 'todo_completed:${todo.id}',
          type: 'todo_completed',
          date: dayKey,
          occurredAt: completedAt,
          todoId: todo.id,
          todoTitle: todo.title,
        ),
      );
    }



    result.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return result;
  }

  static List<JournalActivity> forJourney({
    required Journey journey,
    required HabitsController habits,
    required FocusController focus,
  }) {
    final linked = journey.habitIds.toSet();
    final start = parseDayKeyOrNull(journey.startDate);
    final result = <JournalActivity>[];

    for (final habitId in linked) {
      final habit = habits.byId(habitId);
      if (habit == null) continue;

      for (final entry in habit.completions.entries) {
        final day = parseDayKeyOrNull(entry.key);
        if (day == null || (start != null && day.isBefore(start))) continue;
        result.add(
          JournalActivity(
            id: 'completion:$habitId:${entry.key}',
            type: 'habit_completion',
            date: entry.key,
            occurredAt: entry.value.stamp ??
                day.add(const Duration(hours: 23)),
            habitId: habitId,
            habitName: habit.name,
            journeyId: journey.id,
            journeyTitle: journey.title,
            amount: entry.value.count,
          ),
        );
      }
    }

    for (final session in focus.sessions.where((item) => linked.contains(item.habitId))) {
      final day = session.startedAt.atMidnight;
      if (start != null && day.isBefore(start)) continue;
      result.add(
        JournalActivity(
          id: 'focus:${session.id}',
          type: 'focus',
          date: session.startedAt.dayKey,
          occurredAt: session.startedAt,
          habitId: session.habitId,
          habitName: habits.byId(session.habitId)?.name ?? '',
          journeyId: journey.id,
          journeyTitle: journey.title,
          seconds: session.seconds,
        ),
      );
    }

    for (final milestone in journey.milestones) {
      final completedAt = milestone.completedAt;
      if (completedAt == null) continue;
      result.add(
        JournalActivity(
          id: 'journey_milestone:${milestone.id}',
          type: 'journey_milestone',
          date: completedAt.toLocal().dayKey,
          occurredAt: completedAt,
          journeyId: journey.id,
          journeyTitle: journey.title,
          milestoneId: milestone.id,
          milestoneTitle: milestone.title,
        ),
      );
    }

    result.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return result;
  }

  static DateTime? parseDayKeyOrNull(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return parseDayKey(value);
    } catch (_) {
      return null;
    }
  }
}
