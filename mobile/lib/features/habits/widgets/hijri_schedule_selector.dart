import 'package:flutter/material.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/calendar/calendar_display.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/widgets/minimal_form_fields.dart';

/// choose the calendar a habit follows and, for Hijri, the months
/// it is due in (every day of each chosen month).
class HijriScheduleSelector extends StatelessWidget {
  const HijriScheduleSelector({
    super.key,
    required this.calendar,
    required this.months,
    required this.onCalendarChanged,
    required this.onMonthsChanged,
    this.compact = false,
  });

  final ScheduleCalendar calendar;
  final List<int> months;
  final ValueChanged<ScheduleCalendar> onCalendarChanged;
  final ValueChanged<List<int>> onMonthsChanged;

  /// Minimal style: compact pills and tighter spacing.
  final bool compact;

  Widget _chip(String label, bool selected, VoidCallback onTap) => compact
      ? CompactPill(label: label, selected: selected, onTap: onTap)
      : _Chip(label: label, selected: selected, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: compact ? 7 : 8,
          runSpacing: compact ? 7 : 8,
          children: [
            _chip(
              context.l10n.calendar_gregorian,
              calendar == ScheduleCalendar.gregorian,
              () => onCalendarChanged(ScheduleCalendar.gregorian),
            ),
            _chip(
              context.l10n.calendar_hijri,
              calendar == ScheduleCalendar.hijri,
              () => onCalendarChanged(ScheduleCalendar.hijri),
            ),
          ],
        ),
        if (calendar == ScheduleCalendar.hijri) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: compact ? 7 : 8,
            runSpacing: compact ? 7 : 8,
            children: [
              for (var month = 1; month <= 12; month++)
                _chip(
                  hijriMonthName(month, locale),
                  months.contains(month),
                  () {
                    final next = [...months];
                    months.contains(month) ? next.remove(month) : next.add(month);
                    next.sort();
                    onMonthsChanged(next);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.hijri_months_hint,
            style: TextStyle(fontSize: 13, color: context.tokens.muted),
          ),
        ],
      ],
    );
  }
}

/// “Every day in Ramadan” / “كل يوم في رمضان، شعبان”.
String hijriScheduleLabel(BuildContext context, Habit habit) {
  final locale = Localizations.localeOf(context).languageCode;
  final separator = locale.startsWith('ar') ? '، ' : ', ';
  final names = ([...habit.hijriMonths]..sort())
      .map((m) => hijriMonthName(m, locale))
      .join(separator);
  return context.l10n.every_day_in(names);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : context.tokens.muted,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
