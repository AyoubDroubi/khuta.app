import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:khuta/features/recovery/data/recovery_config.dart';
import 'package:khuta/core/calendar/calendar_display.dart';
import 'package:khuta/core/calendar/hijri_schedule.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/utils/amount_format.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/reminder.dart';
import 'package:khuta/features/habits/data/substep.dart';
import 'package:khuta/features/habits/data/vacation.dart';

enum HabitInterval { daily, weekly, monthly, weekdays, everyXDays }

extension HabitIntervalLabel on HabitInterval {
  String get label => switch (this) {
        HabitInterval.daily => 'Daily',
        HabitInterval.weekly => 'Weekly',
        HabitInterval.monthly => 'Monthly',
        HabitInterval.weekdays => 'Days',
        HabitInterval.everyXDays => 'Interval',
      };

  String get unit => switch (this) {
        HabitInterval.daily => 'day',
        HabitInterval.weekly => 'week',
        HabitInterval.monthly => 'month',
        HabitInterval.weekdays => 'day',
        HabitInterval.everyXDays => 'day',
      };

  bool get isDaySpecific =>
      this == HabitInterval.weekdays || this == HabitInterval.everyXDays;
}

enum ScheduleUnit { days, weeks, months }

/// Which calendar a habit's schedule follows. Hijri habits are due
/// every day of the chosen Hijri months.
enum ScheduleCalendar { gregorian, hijri }

enum HabitKind { positive, negative, quantitative }

enum QuantKind { generic, water, reading, time }

class HabitMaximumTargetVersion {
  const HabitMaximumTargetVersion({
    required this.effectiveDate,
    required this.maximum,
    required this.recordedAt,
  });

  final String effectiveDate;
  final double maximum;
  final DateTime recordedAt;

  Map<String, dynamic> toMap() => {
        'effectiveDate': effectiveDate,
        'maximum': maximum,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };

  factory HabitMaximumTargetVersion.fromMap(Map<String, dynamic> map) =>
      HabitMaximumTargetVersion(
        effectiveDate: map['effectiveDate']?.toString() ?? '',
        maximum: ((map['maximum'] ?? 0) as num).toDouble(),
        recordedAt: DateTime.tryParse(map['recordedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// A minimum daily target that applies from [effectiveDate] on.
/// Reaching it completes the day; the maximum stays the full target. Versions
/// are immutable: a change appends a new one, earlier days keep theirs.
class HabitMinimumTargetVersion {
  const HabitMinimumTargetVersion({
    required this.effectiveDate,
    required this.minimum,
    required this.recordedAt,
  });

  final String effectiveDate;
  final double minimum;
  final DateTime recordedAt;

  Map<String, dynamic> toMap() => {
        'effectiveDate': effectiveDate,
        'minimum': minimum,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };

  factory HabitMinimumTargetVersion.fromMap(Map<String, dynamic> map) =>
      HabitMinimumTargetVersion(
        effectiveDate: map['effectiveDate']?.toString() ?? '',
        minimum: ((map['minimum'] ?? 0) as num).toDouble(),
        recordedAt: DateTime.tryParse(map['recordedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.color,
    required this.order,
    this.icon = 'target',
    this.category = '',
    this.description = '',
    this.perDayTarget = 1,
    this.completions = const {},
    this.interval = HabitInterval.daily,
    this.targetFrequency = 1,
    this.scheduleWeekdays = const [],
    this.scheduleEvery = 2,
    this.scheduleUnit = ScheduleUnit.days,
    this.scheduleCalendar = ScheduleCalendar.gregorian,
    this.hijriMonths = const [],
    this.reminders = const [],
    this.coverPath = '',
    this.coverClarity = 100,
    this.kind = HabitKind.positive,
    this.dailyCost = 0,
    this.unitLabel = '',
    this.incrementAmount = 1,
    this.quantKind = QuantKind.generic,
    this.bookCoverPath = '',
    this.focusMinutes = 25,
    this.focusBreakMinutes = 0,
    this.focusOnly = false,
    this.tracking = false,
    this.difficulty = 0,
    this.startMinute = -1,
    this.durationMinutes = 0,
    this.substeps = const [],
    this.vacations = const [],
    this.restDays = const [],
    this.maximumTargetVersions = const [],
    this.minimumTargetVersions = const [],
    this.recovery = RecoveryConfig.off,
    this.archivedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? AppClock.now();

  final String id;
  final String name;
  final String icon;
  final String category;
  final String description;
  final Color color;
  final int order;

  final double perDayTarget;
  final Map<String, Completion> completions;
  final HabitInterval interval;
  final int targetFrequency;

  final List<int> scheduleWeekdays;

  final int scheduleEvery;

  final ScheduleUnit scheduleUnit;

  /// Gregorian (all existing rules) or Hijri.
  final ScheduleCalendar scheduleCalendar;

  /// Hijri months (1–12) a Hijri habit is due in, every day of each month.
  final List<int> hijriMonths;

  bool get isHijriScheduled => scheduleCalendar == ScheduleCalendar.hijri;

  int get scheduleSpanDays => switch (scheduleUnit) {
        ScheduleUnit.days => scheduleEvery,
        ScheduleUnit.weeks => scheduleEvery * 7,
        ScheduleUnit.months => scheduleEvery * 31,
      };

  final List<Reminder> reminders;

  bool isScheduledOn(DateTime date) {
    if (isHijriScheduled) {
      // Umm al-Qura with the user's adjustment; out of range → not due.
      final h = hijriOf(date, adjust: HijriSchedule.adjust);
      return h != null && hijriMonths.contains(h.month);
    }
    switch (interval) {
      case HabitInterval.weekdays:
        return scheduleWeekdays.contains(date.weekday);
      case HabitInterval.everyXDays:
        if (scheduleEvery <= 0) return false;
        final day = date.atMidnight;
        final start = createdAt.atMidnight;
        if (day.isBefore(start)) return false;
        if (scheduleUnit == ScheduleUnit.months) {
          final months =
              (day.year - start.year) * 12 + day.month - start.month;
          if (months < 0 || months % scheduleEvery != 0) return false;
          final last = DateTime(day.year, day.month + 1, 0).day;
          return day.day == (start.day <= last ? start.day : last);
        }
        final diff = day.epochDay - start.epochDay;
        return diff % scheduleSpanDays == 0;
      case HabitInterval.daily:
      case HabitInterval.weekly:
      case HabitInterval.monthly:
        return true;
    }
  }

  final String coverPath;
  final int coverClarity;
  final DateTime createdAt;

  final HabitKind kind;
  final double dailyCost;
  final String unitLabel;
  final double incrementAmount;
  final QuantKind quantKind;

  final String bookCoverPath;

  final int focusMinutes;
  final int focusBreakMinutes;
  final bool focusOnly;

  final bool tracking;

  final int difficulty;

  static bool weighDifficulty = false;

  int get difficultyWeight => !weighDifficulty
      ? 2
      : switch (difficulty) {
          1 => 1,
          3 => 3,
          _ => 2,
        };

  /// Reminders continue past the minimum and stop at the full target.
  bool silencesRemindersOn(DateTime date) =>
      kind != HabitKind.negative &&
      (minimumVersionFor(date) == null
          ? isCompletedOn(date)
          : isFullTargetOn(date));

  final int startMinute;
  final int durationMinutes;

  static const dayMinutes = 24 * 60;

  bool get isPlanned => startMinute >= 0;

  int get endMinute =>
      (startMinute + durationMinutes).clamp(startMinute, dayMinutes);

  bool get isTimeAmount =>
      kind == HabitKind.quantitative && quantKind == QuantKind.time;

  String amountText(double value) =>
      isTimeAmount ? formatMinutes(value) : formatAmount(value);

  bool get needsFocusSession =>
      focusOnly && kind == HabitKind.positive && substeps.isEmpty;

  bool blocksManualCheck(DateTime date, {bool fromFocus = false}) =>
      needsFocusSession && !fromFocus && !isCompletedOn(date);

  final List<Substep> substeps;

  final List<VacationPeriod> vacations;

  final List<int> restDays;
  final List<HabitMaximumTargetVersion> maximumTargetVersions;
  final List<HabitMinimumTargetVersion> minimumTargetVersions;
  final RecoveryConfig recovery;

  /// The minimum in force on [day], or null when none was ever set (then the
  /// full target is the requirement, as before this feature).
  double? minimumVersionFor(DateTime localDay) {
    HabitMinimumTargetVersion? match;
    for (final version in minimumTargetVersions) {
      if (version.effectiveDate.isEmpty) continue;
      final effective = parseDayKey(version.effectiveDate);
      if (effective.isAfter(localDay.atMidnight)) continue;
      if (match == null) {
        match = version;
        continue;
      }
      final current = parseDayKey(match.effectiveDate);
      if (effective.isAfter(current) ||
          (effective.isSameDay(current) &&
              version.recordedAt.isAfter(match.recordedAt))) {
        match = version;
      }
    }
    return match?.minimum;
  }

  /// What a day needs to count as done: the minimum in force that day (never
  /// above the full target), or the full target when no minimum was set.
  /// Negative habits have no minimum.
  double requiredOn(DateTime localDay) {
    final full = fullTargetOn(localDay);
    if (kind == HabitKind.negative) return full;
    final minimum = minimumVersionFor(localDay);
    if (minimum == null || minimum <= 0) return full;
    return minimum > full ? full : minimum;
  }

  /// The full (maximum) target in force on [localDay]; today's target when no
  /// history exists. Checklist habits use their step count.
  double fullTargetOn(DateTime localDay) =>
      hasSubsteps ? effectiveTarget : (maximumForDay(localDay) ?? effectiveTarget);

  /// The minimum shown in the editor today (equals the target when unset).
  double get currentMinimum => requiredOn(AppClock.today());

  /// True when a count reaches what [localDay] requires.
  bool countCompletes(double count, DateTime localDay) =>
      count >= requiredOn(localDay);

  /// True when the day reached the full (maximum) target, whatever the minimum.
  bool isFullTargetOn(DateTime date) {
    if (kind == HabitKind.negative) return isCompletedOn(date);
    final entry = completions[date.dayKey];
    if (entry == null) return false;
    if (date.atMidnight.isAfter(AppClock.today())) return false;
    if (hasSubsteps) return substeps.every((s) => entry.steps.contains(s.id));
    return entry.count >= fullTargetOn(date);
  }

  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  bool get hasSubsteps => substeps.isNotEmpty;

  double get effectiveTarget =>
      hasSubsteps ? substeps.length.toDouble() : perDayTarget;

  double? maximumForDay(DateTime localDay) {
    HabitMaximumTargetVersion? match;
    for (final version in maximumTargetVersions) {
      if (version.effectiveDate.isEmpty) continue;
      final effective = parseDayKey(version.effectiveDate);
      if (effective.isAfter(localDay.atMidnight)) continue;
      if (match == null) {
        match = version;
        continue;
      }
      final currentDate = parseDayKey(match.effectiveDate);
      if (effective.isAfter(currentDate) ||
          (effective.isSameDay(currentDate) &&
              version.recordedAt.isAfter(match.recordedAt))) {
        match = version;
      }
    }
    if (match != null) return match.maximum;
    return localDay.dayKey == AppClock.today().dayKey ? effectiveTarget : null;
  }

  bool isRestDay(DateTime date) => restDays.contains(date.weekday);

  bool ringsOnWeekday(int weekday) =>
      !restDays.contains(weekday) &&
      (interval != HabitInterval.weekdays ||
          scheduleWeekdays.isEmpty ||
          scheduleWeekdays.contains(weekday));

  bool isPausedOn(DateTime date) =>
      isRestDay(date) || vacations.any((v) => v.contains(date));

  bool isOffDay(DateTime date) => !isScheduledOn(date) || isPausedOn(date);

  bool get isOnVacation => vacations.any((v) => v.isOngoing);

  bool isNeutralOn(DateTime date) =>
      isPausedOn(date) && !completions.containsKey(date.dayKey);

  bool isSatisfiedOn(DateTime date) =>
      isCompletedOn(date) || _doneAheadOf(date);

  bool _doneAheadOf(DateTime date) {
    final span = scheduleSpanDays;
    if (interval != HabitInterval.everyXDays || span <= 1) return false;
    final floor = startedAt;
    var cursor = date.atMidnight;
    for (var step = 1; step < span; step++) {
      cursor = cursor.addDays(-1);
      if (cursor.isBefore(floor)) return false;
      if (isCompletedOn(cursor)) return true;
      if (isScheduledOn(cursor)) return false;
    }
    return false;
  }

  int _periodOf(DateTime day) => interval == HabitInterval.weekly
      ? day.startOfWeek(DateTime.monday).epochDay
      : day.year * 12 + day.month;

  late final Map<int, int> _periodDone = _countPeriods();

  Map<int, int> _countPeriods() {
    if (interval != HabitInterval.weekly && interval != HabitInterval.monthly) {
      return const {};
    }
    final counts = <int, int>{};
    for (final key in completions.keys) {
      final day = parseDayKey(key);
      if (!isCompletedOn(day)) continue;
      final period = _periodOf(day);
      counts[period] = (counts[period] ?? 0) + 1;
    }
    return counts;
  }

  bool isCoveredOn(DateTime date) {
    var cursor = date.atMidnight;
    if (cursor.isAfter(AppClock.today()) || cursor.isBefore(startedAt)) {
      return false;
    }
    if (interval == HabitInterval.weekly ||
        interval == HabitInterval.monthly) {
      if (isPausedOn(cursor) || isCompletedOn(cursor)) return false;
      return (_periodDone[_periodOf(cursor)] ?? 0) >= targetFrequency;
    }
    final span = scheduleSpanDays;
    if (interval != HabitInterval.everyXDays || span <= 1) return false;
    if (isScheduledOn(cursor)) return false;
    final floor = startedAt;
    for (var step = 1; step < span; step++) {
      cursor = cursor.addDays(-1);
      if (cursor.isBefore(floor)) return false;
      if (isCompletedOn(cursor)) return true;
      if (isScheduledOn(cursor)) return false;
    }
    return false;
  }

  late final DateTime startedAt = _startedAt();

  DateTime _startedAt() {
    var first = createdAt.atMidnight;
    for (final key in completions.keys) {
      final day = parseDayKey(key);
      if (day.isBefore(first)) first = day;
    }
    return first;
  }

  bool isCompletedOn(DateTime date) {
    final entry = completions[date.dayKey];
    final negative = kind == HabitKind.negative;
    if (entry == null && !negative) return false;
    final day = date.atMidnight;
    if (day.isAfter(AppClock.today())) return false;
    if (negative) {
      return day.isBefore(startedAt) ? false : entry == null;
    }
    if (hasSubsteps) {
      final done = substeps.where((s) => entry!.steps.contains(s.id)).length;
      return done >= requiredOn(date);
    }
    return entry!.count >= requiredOn(date);
  }

  bool isRelapseOn(DateTime date) =>
      kind == HabitKind.negative && completions.containsKey(date.dayKey);

  bool get hasCost => kind == HabitKind.negative && dailyCost > 0;

  late final int cleanDays = _cleanDays();

  int _cleanDays() {
    if (kind != HabitKind.negative) return 0;
    final floor = startedAt;
    final span = AppClock.today().epochDay - floor.epochDay + 1;
    if (span <= 0) return 0;
    return span - _relapsesSince(floor);
  }

  int _relapsesSince(DateTime floor) {
    final today = AppClock.today();
    var relapses = 0;
    for (final entry in completions.values) {
      final day = parseDayKey(entry.date);
      if (!day.isBefore(floor) && !day.isAfter(today)) relapses++;
    }
    return relapses;
  }

  double get moneySaved => hasCost ? cleanDays * dailyCost : 0;

  late final int totalCompletions = _totalCompletions();

  int _totalCompletions() {
    final ids = substeps.map((s) => s.id).toSet();
    return completions.values.where((c) {
      final day = c.day;
      if (day == null) return false;
      if (hasSubsteps) return ids.where(c.steps.contains).length >= requiredOn(day);
      return c.count >= requiredOn(day);
    }).length;
  }

  bool get isDoneForNow {
    if (kind == HabitKind.negative) return false;
    final now = AppClock.now();
    return isOffDay(now) || isCompletedOn(now) || isCoveredOn(now);
  }

  double _dayValue(DateTime date) {
    final day = date.atMidnight;
    if (day.isBefore(startedAt) || day.isAfter(AppClock.today())) {
      return 0;
    }
    if (kind == HabitKind.negative) {
      return completions.containsKey(date.dayKey) ? 0.0 : 1.0;
    }
    final count = completions[date.dayKey]?.count ?? 0;
    final target = requiredOn(date);
    if (target <= 0) return count > 0 ? 1 : 0;
    return (count / target).clamp(0.0, 1.0);
  }

  late final double strength = _strength();

  double _strength() {
    if (completions.isEmpty && kind != HabitKind.negative) return 0;
    final now = AppClock.today();
    final floor = startedAt;
    const halfLife = 12.0;
    const window = 90;
    var score = 0.0;
    var norm = 0.0;
    for (var i = 0; i < window; i++) {
      final day = now.addDays(-i);
      if (day.isBefore(floor) ||
          !isScheduledOn(day) ||
          isNeutralOn(day) ||
          isCoveredOn(day)) {
        continue;
      }
      final weight = math.pow(0.5, i / halfLife).toDouble();
      norm += weight;
      score += weight * _dayValue(day);
    }
    return norm == 0 ? 0 : (score / norm).clamp(0.0, 1.0);
  }

  late final int consistency = (strength * 100).round();

  int _countInRange(DateTime start, DateTime end) {
    var count = 0;
    for (var i = 0; i <= end.epochDay - start.epochDay; i++) {
      if (isCompletedOn(start.addDays(i))) count++;
    }
    return count;
  }

  late final int currentStreak = _currentStreak();

  int _currentStreak() {
    final floor = startedAt;

    if (kind == HabitKind.negative) {
      var cursor = AppClock.today();
      var streak = 0;
      while (!cursor.isBefore(floor)) {
        if (isNeutralOn(cursor)) {
        } else if (isCompletedOn(cursor)) {
          streak++;
        } else {
          break;
        }
        cursor = cursor.addDays(-1);
      }
      return streak;
    }

    if (completions.isEmpty) return 0;
    // Hijri habits: days outside the chosen months are neutral, so a streak
    // carries from one season to the next.
    if (isHijriScheduled) return _daySpecificCurrentStreak();
    final now = AppClock.now();

    switch (interval) {
      case HabitInterval.daily:
        var cursor = now.atMidnight;
        if (!isCompletedOn(cursor) && !isNeutralOn(cursor)) {
          cursor = cursor.addDays(-1);
          if (!isCompletedOn(cursor) && !isNeutralOn(cursor)) return 0;
        }
        var streak = 0;
        while (!cursor.isBefore(floor)) {
          if (isNeutralOn(cursor)) {
          } else if (isCompletedOn(cursor)) {
            streak++;
          } else {
            break;
          }
          cursor = cursor.addDays(-1);
        }
        return streak;

      case HabitInterval.weekly:
        var weekStart = now.addDays(-(now.weekday - 1));
        var streak = 0;
        if (_countInRange(weekStart, weekStart.addDays(6)) >=
            targetFrequency) {
          streak++;
        }
        weekStart = weekStart.addDays(-7);
        while (_countInRange(
                weekStart, weekStart.addDays(6)) >=
            targetFrequency) {
          streak++;
          weekStart = weekStart.addDays(-7);
        }
        return streak;

      case HabitInterval.monthly:
        var monthStart = DateTime(now.year, now.month, 1);
        final monthEnd =
            DateTime(now.year, now.month + 1, 1).addDays(-1);
        var streak = 0;
        if (_countInRange(monthStart, monthEnd) >= targetFrequency) streak++;
        monthStart = DateTime(monthStart.year, monthStart.month - 1, 1);
        while (true) {
          final end = DateTime(monthStart.year, monthStart.month + 1, 1)
              .addDays(-1);
          if (_countInRange(monthStart, end) < targetFrequency) break;
          streak++;
          monthStart = DateTime(monthStart.year, monthStart.month - 1, 1);
        }
        return streak;

      case HabitInterval.weekdays:
      case HabitInterval.everyXDays:
        return _daySpecificCurrentStreak();
    }
  }

  int _daySpecificCurrentStreak() {
    final floor = startedAt;
    final today = AppClock.today();
    var cursor = today;
    var streak = 0;
    while (!cursor.isBefore(floor)) {
      if (isNeutralOn(cursor) || !isScheduledOn(cursor)) {
        cursor = cursor.addDays(-1);
        continue;
      }
      if (isSatisfiedOn(cursor)) {
        streak++;
      } else if (cursor.isAtSameMomentAs(today)) {
      } else {
        break;
      }
      cursor = cursor.addDays(-1);
    }
    return streak;
  }

  int _daySpecificLongestStreak() {
    var cursor = startedAt;
    final end = AppClock.today();
    var best = 0;
    var run = 0;
    while (!cursor.isAfter(end)) {
      if (isNeutralOn(cursor) || !isScheduledOn(cursor)) {
        cursor = cursor.addDays(1);
        continue;
      }
      if (isSatisfiedOn(cursor)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
      cursor = cursor.addDays(1);
    }
    return best;
  }

  late final int longestStreak = _longestStreak();

  int _longestStreak() {
    if (kind == HabitKind.negative) {
      var cursor = startedAt;
      final end = AppClock.today();
      var best = 0;
      var run = 0;
      while (!cursor.isAfter(end)) {
        if (isNeutralOn(cursor)) {
        } else if (isCompletedOn(cursor)) {
          run++;
          if (run > best) best = run;
        } else {
          run = 0;
        }
        cursor = cursor.addDays(1);
      }
      return best;
    }

    if (completions.isEmpty) return 0;
    if (isHijriScheduled) return _daySpecificLongestStreak();
    final dates = completions.keys.map(parseDayKey).toList()
      ..sort((a, b) => a.compareTo(b));

    switch (interval) {
      case HabitInterval.daily:
        var cursor = startedAt;
        final end = AppClock.today();
        var best = 0;
        var run = 0;
        while (!cursor.isAfter(end)) {
          if (isNeutralOn(cursor)) {
          } else if (isCompletedOn(cursor)) {
            run++;
            if (run > best) best = run;
          } else {
            run = 0;
          }
          cursor = cursor.addDays(1);
        }
        return best;

      case HabitInterval.weekly:
        var start = dates.first.addDays(-(dates.first.weekday - 1));
        final end =
            dates.last.addDays(7 - dates.last.weekday);
        var best = 0;
        var run = 0;
        while (!start.isAfter(end)) {
          if (_countInRange(start, start.addDays(6)) >=
              targetFrequency) {
            run++;
          } else {
            run = 0;
          }
          if (run > best) best = run;
          start = start.addDays(7);
        }
        return best;

      case HabitInterval.monthly:
        var start = DateTime(dates.first.year, dates.first.month, 1);
        final end = DateTime(dates.last.year, dates.last.month + 1, 1)
            .addDays(-1);
        var best = 0;
        var run = 0;
        while (!start.isAfter(end)) {
          final mEnd = DateTime(start.year, start.month + 1, 1)
              .addDays(-1);
          if (_countInRange(start, mEnd) >= targetFrequency) {
            run++;
          } else {
            run = 0;
          }
          if (run > best) best = run;
          start = DateTime(start.year, start.month + 1, 1);
        }
        return best;

      case HabitInterval.weekdays:
      case HabitInterval.everyXDays:
        return _daySpecificLongestStreak();
    }
  }

  Habit copyWith({
    String? name,
    String? icon,
    String? category,
    String? description,
    Color? color,
    int? order,
    double? perDayTarget,
    Map<String, Completion>? completions,
    HabitInterval? interval,
    int? targetFrequency,
    List<int>? scheduleWeekdays,
    int? scheduleEvery,
    ScheduleUnit? scheduleUnit,
    ScheduleCalendar? scheduleCalendar,
    List<int>? hijriMonths,
    List<Reminder>? reminders,
    String? coverPath,
    int? coverClarity,
    HabitKind? kind,
    double? dailyCost,
    String? unitLabel,
    double? incrementAmount,
    QuantKind? quantKind,
    String? bookCoverPath,
    int? focusMinutes,
    int? focusBreakMinutes,
    bool? focusOnly,
    bool? tracking,
    int? difficulty,
    int? startMinute,
    int? durationMinutes,
    List<Substep>? substeps,
    List<VacationPeriod>? vacations,
    List<int>? restDays,
    List<HabitMaximumTargetVersion>? maximumTargetVersions,
    List<HabitMinimumTargetVersion>? minimumTargetVersions,
    RecoveryConfig? recovery,
    DateTime? archivedAt,
    bool clearArchived = false,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      description: description ?? this.description,
      color: color ?? this.color,
      order: order ?? this.order,
      perDayTarget: perDayTarget ?? this.perDayTarget,
      completions: completions ?? this.completions,
      interval: interval ?? this.interval,
      targetFrequency: targetFrequency ?? this.targetFrequency,
      scheduleWeekdays: scheduleWeekdays ?? this.scheduleWeekdays,
      scheduleEvery: scheduleEvery ?? this.scheduleEvery,
      scheduleUnit: scheduleUnit ?? this.scheduleUnit,
      scheduleCalendar: scheduleCalendar ?? this.scheduleCalendar,
      hijriMonths: hijriMonths ?? this.hijriMonths,
      reminders: reminders ?? this.reminders,
      coverPath: coverPath ?? this.coverPath,
      coverClarity: coverClarity ?? this.coverClarity,
      kind: kind ?? this.kind,
      dailyCost: dailyCost ?? this.dailyCost,
      unitLabel: unitLabel ?? this.unitLabel,
      incrementAmount: incrementAmount ?? this.incrementAmount,
      quantKind: quantKind ?? this.quantKind,
      bookCoverPath: bookCoverPath ?? this.bookCoverPath,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      focusOnly: focusOnly ?? this.focusOnly,
      tracking: tracking ?? this.tracking,
      difficulty: difficulty ?? this.difficulty,
      focusBreakMinutes: focusBreakMinutes ?? this.focusBreakMinutes,
      startMinute: startMinute ?? this.startMinute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      substeps: substeps ?? this.substeps,
      vacations: vacations ?? this.vacations,
      restDays: restDays ?? this.restDays,
      maximumTargetVersions:
          maximumTargetVersions ?? this.maximumTargetVersions,
      minimumTargetVersions:
          minimumTargetVersions ?? this.minimumTargetVersions,
      recovery: recovery ?? this.recovery,
      archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'category': category,
        'description': description,
        'color': color.toARGB32(),
        'order': order,
        'numberOfCompletionsPerDay': perDayTarget,
        'completions':
            completions.map((key, value) => MapEntry(key, value.toMap())),
        'interval': interval.index,
        'targetFrequency': targetFrequency,
        'scheduleWeekdays': scheduleWeekdays,
        'scheduleEvery': scheduleEvery,
        'scheduleUnit': scheduleUnit.index,
        'scheduleCalendar': scheduleCalendar.index,
        'hijriMonths': hijriMonths,
        'reminders': reminders.map((r) => r.toMap()).toList(),
        'coverPath': coverPath,
        'coverClarity': coverClarity,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind.index,
        'dailyCost': dailyCost,
        'unitLabel': unitLabel,
        'incrementAmount': incrementAmount,
        'quantKind': quantKind.index,
        'bookCoverPath': bookCoverPath,
        'focusMinutes': focusMinutes,
        'focusBreakMinutes': focusBreakMinutes,
        'focusOnly': focusOnly,
        'tracking': tracking,
        'difficulty': difficulty,
        'startMinute': startMinute,
        'durationMinutes': durationMinutes,
        'substeps': substeps.map((s) => s.toMap()).toList(),
        'vacations': vacations.map((v) => v.toMap()).toList(),
        'restDays': restDays,
        'maximumTargetVersions':
            maximumTargetVersions.map((version) => version.toMap()).toList(),
        if (recovery.enabled) 'recovery': recovery.toMap(),
        if (minimumTargetVersions.isNotEmpty)
          'minimumTargetVersions':
              minimumTargetVersions.map((version) => version.toMap()).toList(),
        if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
      };

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: (map['icon'] ?? 'target') as String,
        category: (map['category'] ?? '') as String,
        description: (map['description'] ?? '') as String,
        color: Color(map['color'] as int),
        order: (map['order'] ?? 0) as int,
        perDayTarget:
            ((map['numberOfCompletionsPerDay'] ?? 1) as num).toDouble(),
        completions: (map['completions'] as Map?)?.map(
              (key, value) => MapEntry(
                key as String,
                Completion.fromMap(Map<String, dynamic>.from(value as Map)),
              ),
            ) ??
            const {},
        // Hijri habits are always due every day of their months; normalise malformed data.
        interval: ((map['scheduleCalendar'] ?? 0) as num).toInt() ==
                ScheduleCalendar.hijri.index
            ? HabitInterval.daily
            : HabitInterval.values[(map['interval'] ?? 0) as int],
        targetFrequency: (map['targetFrequency'] ?? 1) as int,
        scheduleWeekdays: (map['scheduleWeekdays'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
        scheduleEvery: (map['scheduleEvery'] ?? 2) as int,
        scheduleUnit: ScheduleUnit.values[((map['scheduleUnit'] ?? 0) as num)
            .toInt()
            .clamp(0, ScheduleUnit.values.length - 1)],
        scheduleCalendar: ScheduleCalendar.values[
            ((map['scheduleCalendar'] ?? 0) as num)
                .toInt()
                .clamp(0, ScheduleCalendar.values.length - 1)],
        hijriMonths: (map['hijriMonths'] as List?)
                ?.map((e) => (e as num).toInt())
                .where((m) => m >= 1 && m <= 12)
                .toList() ??
            const [],
        reminders: map['reminders'] == null
            ? const []
            : (map['reminders'] as List)
                .map((r) => Reminder.fromMap(Map<String, dynamic>.from(r as Map)))
                .toList(),
        coverPath: (map['coverPath'] ?? '') as String,
        coverClarity: ((map['coverClarity'] ?? 100) as num).toInt(),
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'] as String)
            : null,
        kind: HabitKind.values[(map['kind'] ?? 0) as int],
        dailyCost: ((map['dailyCost'] ?? 0) as num).toDouble(),
        unitLabel: (map['unitLabel'] ?? '') as String,
        incrementAmount: ((map['incrementAmount'] ?? 1) as num).toDouble(),
        quantKind: QuantKind.values[(map['quantKind'] ?? 0) as int],
        bookCoverPath: (map['bookCoverPath'] ?? '') as String,
        focusMinutes: ((map['focusMinutes'] ?? 25) as num).toInt(),
        focusBreakMinutes:
            ((map['focusBreakMinutes'] ?? 0) as num).toInt(),
        focusOnly: (map['focusOnly'] ?? false) as bool,
        tracking: (map['tracking'] ?? false) as bool,
        difficulty: ((map['difficulty'] ?? 0) as num).toInt().clamp(0, 3),
        startMinute: ((map['startMinute'] ?? -1) as num).toInt(),
        durationMinutes: ((map['durationMinutes'] ?? 0) as num).toInt(),
        substeps: map['substeps'] == null
            ? const []
            : (map['substeps'] as List)
                .map((s) => Substep.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList(),
        vacations: map['vacations'] == null
            ? const []
            : (map['vacations'] as List)
                .map((v) =>
                    VacationPeriod.fromMap(Map<String, dynamic>.from(v as Map)))
                .toList(),
        restDays:
            (map['restDays'] as List?)?.map((e) => e as int).toList() ?? const [],
        maximumTargetVersions: (map['maximumTargetVersions'] as List? ?? const [])
            .map((item) => HabitMaximumTargetVersion.fromMap(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(),
        recovery: RecoveryConfig.fromMap(map['recovery']),
        minimumTargetVersions: (map['minimumTargetVersions'] as List? ?? const [])
            .map((item) => HabitMinimumTargetVersion.fromMap(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(),
        archivedAt: map['archivedAt'] == null
            ? null
            : DateTime.tryParse(map['archivedAt'] as String),
      );

  String toJson() => json.encode(toMap());

  factory Habit.fromJson(String source) =>
      Habit.fromMap(json.decode(source) as Map<String, dynamic>);
}
