import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/recovery/data/recovery_config.dart';

/// Pure, clock-injectable Recovery rules. Nothing here reads or writes
/// completions: eligibility and reminder times are derived from them.
class RecoveryPlan {
  const RecoveryPlan._();

  static const defaultThresholdHours = 24;
  static const maxThresholdHours = 24 * 60;

  /// Wall-clock addition: a day with a daylight-saving change still counts as
  /// 24 hours on the clock, so reminders keep their local time.
  static DateTime _plusHours(DateTime at, int hours) =>
      DateTime(at.year, at.month, at.day, at.hour + hours, at.minute);

  static bool _due(Habit habit, DateTime day) =>
      !day.isBefore(habit.startedAt) &&
      habit.isScheduledOn(day) &&
      !habit.isNeutralOn(day);

  static bool supports(Habit habit) =>
      habit.kind != HabitKind.negative && !habit.tracking;

  /// Moment of the latest completed day (minimum counts), or the day the habit
  /// started when it was never completed.
  static DateTime lastActivity(Habit habit, DateTime now) {
    DateTime? best;
    for (final entry in habit.completions.values) {
      final day = entry.day;
      if (day == null || day.isAfter(now.atMidnight)) continue;
      if (!habit.isCompletedOn(day)) continue;
      final at = entry.stamp ?? DateTime(day.year, day.month, day.day, 12);
      if (best == null || at.isAfter(best)) best = at;
    }
    return best ?? habit.startedAt;
  }

  /// When the habit becomes eligible: last activity plus the shared threshold.
  static DateTime eligibleAt(Habit habit, DateTime now, int thresholdHours) =>
      _plusHours(lastActivity(habit, now), thresholdHours);

  static bool isEligible(Habit habit, DateTime now, int thresholdHours) {
    final config = habit.recovery;
    if (!config.enabled || !supports(habit) || habit.isArchived) return false;
    final today = now.atMidnight;
    if (!_due(habit, today)) return false;
    if (habit.isCompletedOn(today)) return false;
    return !now.isBefore(eligibleAt(habit, now, thresholdHours));
  }

  /// The reminders of the current cycle that are still ahead of [now]. The
  /// full sequence is derived from the last completion, so reminders that
  /// already fired are not repeated and the configured count is authoritative.
  static List<DateTime> reminders(Habit habit, DateTime now, int thresholdHours) {
    final config = habit.recovery;
    if (!config.enabled ||
        !supports(habit) ||
        habit.isArchived ||
        config.count <= 0) {
      return const [];
    }
    var start = eligibleAt(habit, now, thresholdHours);
    final since = config.enabledAt;
    if (since != null && since.isAfter(start)) start = since;
    final first = _plusHours(start, config.firstDelayHours);
    final out = <DateTime>[];
    var slot = 0;
    var guard = 0;
    while (out.length < config.count && guard++ < 800) {
      final at = _slot(config, first, slot++);
      if (_due(habit, at.atMidnight)) out.add(at);
    }
    return [for (final at in out) if (!at.isBefore(now)) at];
  }

  static DateTime _slot(RecoveryConfig config, DateTime first, int slot) {
    if (slot == 0) return first;
    if (config.fixedTime) {
      return DateTime(
        first.year,
        first.month,
        first.day + slot,
        config.hour,
        config.minute,
      );
    }
    return _plusHours(first, config.repeatHours * slot);
  }

  /// Habits for the Today section, in their stored order.
  static List<Habit> eligible(
    Iterable<Habit> habits,
    DateTime now,
    int thresholdHours,
  ) =>
      [
        for (final habit in habits)
          if (isEligible(habit, now, thresholdHours)) habit,
      ];
}
