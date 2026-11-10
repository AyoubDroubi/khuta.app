import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/widgets/check_history.dart';

IconData habitMarkIcon(Habit habit) =>
    habit.tracking ? LucideIcons.history : LucideIcons.flame;

String habitMarkLabel(BuildContext context, Habit habit) => habit.tracking
    ? lastCheckLabel(context, habit)
    : streakLabel(context, habit);

String streakLabel(BuildContext context, Habit habit) {
  final value = '${habit.currentStreak}';
  return switch (habit.interval) {
    HabitInterval.weekly => context.l10n.streak_unit_week(habit.currentStreak),
    HabitInterval.monthly => context.l10n.streak_unit_month(habit.currentStreak),
    _ => value,
  };
}
