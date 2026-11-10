import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/calendar/calendar_display.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/settings/widgets/minimal_settings_widgets.dart';

/// calendar display mode and Hijri adjustment, shared by
/// the Classic, Minimal and Express settings pages.
List<String> calendarModeLabels(BuildContext context) => [
      context.l10n.calendar_gregorian,
      context.l10n.calendar_hijri,
      context.l10n.calendar_gregorian_hijri,
      context.l10n.calendar_hijri_gregorian,
    ];

const _adjustOptions = [-2, -1, 0, 1, 2];

String hijriAdjustLabel(int days) => days > 0 ? '+$days' : '$days';

Future<void> showCalendarModeSheet(
  BuildContext context,
  SettingsController settings,
) =>
    showOptionSheet(
      context,
      title: context.l10n.calendar,
      options: calendarModeLabels(context),
      index: settings.calendarMode.index,
      onSelected: (i) => settings.setCalendarMode(CalendarMode.values[i]),
    );

Future<void> showHijriAdjustSheet(
  BuildContext context,
  SettingsController settings,
) =>
    showOptionSheet(
      context,
      title: context.l10n.hijri_adjust,
      options: [for (final d in _adjustOptions) hijriAdjustLabel(d)],
      index: _adjustOptions.indexOf(settings.hijriAdjust),
      onSelected: (i) async {
        await settings.setHijriAdjust(_adjustOptions[i]);
        // Hijri habit schedules follow the adjustment.
        if (context.mounted) await context.read<HabitsController>().applyHijriAdjust();
      },
    );

/// Wraps a Gregorian day label with the Hijri date per the user's calendar
/// mode. From `build` it listens to settings changes; pass `listen: false`
/// from callbacks such as tap handlers.
extension CalendarDayLabel on BuildContext {
  String calendarDay(
    DateTime date,
    String gregorian, {
    bool withYear = true,
    bool listen = true,
  }) {
    final settings = Provider.of<SettingsController>(this, listen: listen);
    return dayLabel(
      date,
      gregorian: gregorian,
      locale: Localizations.localeOf(this).languageCode,
      mode: settings.calendarMode,
      adjust: settings.hijriAdjust,
      withYear: withYear,
    );
  }
}
