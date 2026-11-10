import 'package:flutter/widgets.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/habits/data/habit.dart';

extension MinimumLabel on Habit {
  /// "min 4  ·  6 left" when today's minimum is lower than the full target.
  String? minimumSuffix(BuildContext context) {
    if (kind == HabitKind.negative) return null;
    final today = AppClock.today();
    final minimum = requiredOn(today);
    if (minimum >= fullTargetOn(today)) return null;
    final done = completions[today.dayKey]?.count ?? 0;
    final left = fullTargetOn(today) - done;
    final min = context.l10n.minimum_suffix(amountText(minimum));
    if (done <= 0 || left <= 0) return min;
    return '$min  ·  ${context.l10n.amount_left(amountText(left))}';
  }
}
