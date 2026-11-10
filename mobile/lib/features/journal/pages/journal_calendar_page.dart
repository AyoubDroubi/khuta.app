import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/inset_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journal/data/journal_projection.dart';
import 'package:khuta/features/journal/pages/journal_page.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

class JournalCalendarPage extends StatefulWidget {
  const JournalCalendarPage({super.key, required this.selected});

  final DateTime selected;

  @override
  State<JournalCalendarPage> createState() => _JournalCalendarPageState();
}

class _JournalCalendarPageState extends State<JournalCalendarPage> {
  late DateTime _selected = DateUtils.dateOnly(widget.selected);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final minimal = settings.isMinimalStyle;
    final journal = context.watch<JournalController>();
    final activityDays = JournalProjection.daysWithActivity(
      habits: context.watch<HabitsController>(),
      focus: context.watch<FocusController>(),
      todos: context.watch<TodosController>(),
    );
    final count = <String>{
      ...journal.daysWithEntries,
      ...activityDays,
    }.length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: minimal ? 52 : null,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.arrowLeftDir),
          onPressed: AppNavigator.pop,
        ),
        title: minimal ? null : Text(context.l10n.journal_calendar),
      ),
      body: ListView(
        padding: context.pagePadding(16, 8, 16, 28),
        children: [
          if (minimal)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                context.l10n.journal_calendar,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.colors.onSurface,
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CalendarDatePicker(
                initialDate: _selected,
                firstDate: DateTime(2000),
                lastDate: DateUtils.dateOnly(DateTime.now()),
                onDateChanged: (value) =>
                    setState(() => _selected = DateUtils.dateOnly(value)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            count == 0
                ? context.l10n.journal_empty
                : '$count ${context.l10n.days.toLowerCase()}',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.tokens.muted),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () => AppNavigator.push(JournalPage(date: _selected)),
              icon: const Icon(LucideIcons.bookOpenText, size: 18),
              label: Text(context.l10n.journal),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
