import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/utils/responsive.dart';
import 'package:khuta/core/widgets/sheet_action.dart';
import 'package:khuta/core/widgets/sheet_type.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/habits/widgets/habit_checklist.dart';
import 'package:khuta/features/settings/widgets/calendar_settings.dart';

Future<void> showDayActionsSheet(
  BuildContext context, {
  required Habit habit,
  required DateTime date,
}) {
  final locale = Localizations.localeOf(context).toString();
  final habits = context.read<HabitsController>();
  final paused = habit.isPausedOn(date);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: phoneWidth,
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
              child: Text(
                context.calendarDay(date, DateFormat.yMMMMEEEEd(locale).format(date)),
                style: sheetTitleStyle(context, size: 17),
              ),
            ),
            if (habit.hasSubsteps &&
                !date.atMidnight.isAfter(AppClock.today())) ...[
              Consumer<HabitsController>(
                builder: (inner, controller, _) => HabitChecklist(
                  habit: controller.byId(habit.id) ?? habit,
                  date: date,
                  dense: true,
                  header: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!habit.isRestDay(date) &&
                !date.atMidnight.isAfter(AppClock.today())) ...[
              SheetAction(
                icon: LucideIcons.palmtree,
                label: paused
                    ? context.l10n.vacation_day_off
                    : context.l10n.vacation_day_on,
                accent: context.tokens.info,
                highlighted: paused,
                onTap: () {
                  Navigator.of(sheet).pop();
                  habits.toggleVacationDay(habit.id, date);
                },
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(sheet).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.surfaceContainerHighest,
                  foregroundColor: context.colors.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  context.l10n.cancel,
                  style: sheetActionStyle(context),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
