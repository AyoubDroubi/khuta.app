import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/reminder.dart';

class ReminderSchedule {
  const ReminderSchedule._();

  static const slotsPerReminder = 64;

  static const quietWeeks = 4;

  static const _quietIdBase = 100000000;

  static int quietId(int id, int week) =>
      week <= 1 ? id : id + _quietIdBase * (week - 1);

  static int notificationId(String habitId, String reminderId, int slot) {
    final habit = habitId.hashCode.abs() % 10000;
    final reminder = reminderId.hashCode.abs() % 100;
    return (habit * 100 + reminder) * slotsPerReminder + slot;
  }

  static const maxHourlyPerDay = 8;

  static List<int> hourlySlots({
    required int hour,
    required int minute,
    required int everyHours,
  }) {
    if (everyHours < 1) return [hour * 60 + minute];
    final start = hour * 60 + minute;
    final step = everyHours * 60;
    final slots = <int>[];
    for (var at = start; at < 24 * 60 && slots.length < maxHourlyPerDay; at += step) {
      slots.add(at);
    }
    return slots;
  }

  /// How far ahead Hijri reminders look for the next due day (a whole Hijri
  /// year plus margin), and how many due days one reminder covers.
  static const hijriHorizonDays = 400;
  static const hijriMaxDays = 31;

  /// One-off fire times for a Hijri-scheduled habit: every slot of
  /// [reminder] on each upcoming due day (scheduled, not paused, reminder
  /// weekday allowed), at or after [from], capped at [slotsPerReminder]
  /// notifications. Rescheduled daily, so the window keeps rolling.
  static List<DateTime> hijriFireTimes({
    required Habit habit,
    required Reminder reminder,
    required DateTime now,
    required DateTime from,
  }) {
    final slots = reminder.isHourly
        ? hourlySlots(
            hour: reminder.hour,
            minute: reminder.minute,
            everyHours: reminder.everyHours,
          )
        : [reminder.hour * 60 + reminder.minute];
    final maxDays = (slotsPerReminder ~/ slots.length).clamp(1, hijriMaxDays);
    final times = <DateTime>[];
    var days = 0;
    for (var i = 0; i < hijriHorizonDays && days < maxDays; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (!habit.isScheduledOn(day) || habit.isPausedOn(day)) continue;
      if (!habit.ringsOnWeekday(day.weekday)) continue;
      if (reminder.days.isNotEmpty && !reminder.days.contains(day.weekday)) {
        continue;
      }
      var added = false;
      for (final at in slots) {
        final when = DateTime(day.year, day.month, day.day, at ~/ 60, at % 60);
        if (when.isBefore(from)) continue;
        times.add(when);
        added = true;
      }
      if (added) days++;
    }
    return times.take(slotsPerReminder).toList();
  }

  static int hourlyId(String habitId, String reminderId, int day, int slot) =>
      notificationId(habitId, reminderId, (day - 1) * maxHourlyPerDay + slot);

  static const todoIdBase = 1000000000;

  static int todoNotificationId(String todoId) =>
      todoIdBase + todoId.hashCode.abs() % 100000000;

  static DateTime? todoFireAt({
    required DateTime now,
    required bool done,
    DateTime? due,
    int? minutes,
  }) {
    if (done || due == null || minutes == null) return null;
    final at = DateTime(due.year, due.month, due.day).add(
      Duration(minutes: minutes),
    );
    return at.isAfter(now) ? at : null;
  }

  static DateTime nextWeekly({
    required DateTime now,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    while (when.weekday != weekday) {
      when = when.add(const Duration(days: 1));
    }
    return when.isBefore(now) ? when.add(const Duration(days: 7)) : when;
  }

  static DateTime nextDaily({
    required DateTime now,
    required int hour,
    required int minute,
  }) {
    final when = DateTime(now.year, now.month, now.day, hour, minute);
    return when.isBefore(now)
        ? DateTime(now.year, now.month, now.day + 1, hour, minute)
        : when;
  }
}
