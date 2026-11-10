import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/app/theme/habit_ink.dart';
import 'package:khuta/core/i18n/date_labels.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/widgets/habit_form_schedule.dart';
import 'package:khuta/features/habits/widgets/hijri_schedule_selector.dart';

String habitFrequencyLabel(BuildContext context, Habit habit) {
  if (habit.isHijriScheduled) return hijriScheduleLabel(context, habit);
  return switch (habit.interval) {
    HabitInterval.daily => context.l10n.daily,
    HabitInterval.weekly =>
      context.l10n.freq_per_week_short('${habit.targetFrequency}'),
    HabitInterval.monthly =>
      context.l10n.freq_per_month_short('${habit.targetFrequency}'),
    HabitInterval.weekdays => _weekdaysLabel(context, habit),
    HabitInterval.everyXDays =>
      scheduleEveryLabel(context, habit.scheduleEvery, habit.scheduleUnit),
  };
}

String _weekdaysLabel(BuildContext context, Habit habit) {
  final days = [...habit.scheduleWeekdays]..sort();
  if (days.isEmpty) return context.l10n.daily;
  if (days.length == 7) return context.l10n.every_day;
  final names = WeekdayLabels.shortMonFirst(
    Localizations.localeOf(context).languageCode,
  );
  return days.map((d) => names[d - 1]).join(', ');
}

bool habitHasExplicitFrequency(Habit habit) =>
    habit.isHijriScheduled || habit.interval != HabitInterval.daily;

class FrequencyChip extends StatelessWidget {
  const FrequencyChip({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final c = habit.color;
    final ink = context.habitInk(habit.color, min: 4.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.repeat, size: 13, color: ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              habitFrequencyLabel(context, habit),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
