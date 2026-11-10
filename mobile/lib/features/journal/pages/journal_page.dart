import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/extensions/inset_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/core/widgets/app_confirm_dialog.dart';
import 'package:khuta/core/widgets/classic_ui.dart';
import 'package:khuta/core/widgets/delete_sheet.dart';
import 'package:khuta/core/widgets/photo_deck.dart';
import 'package:khuta/core/widgets/photo_viewer.dart';
import 'package:khuta/features/focus/pages/focus_history_page.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/data/journal_projection.dart';
import 'package:khuta/features/journal/pages/journal_calendar_page.dart';
import 'package:khuta/features/journal/pages/journal_entry_editor_page.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:khuta/features/todos/widgets/todo_composer.dart';
import 'package:khuta/features/todos/widgets/todo_preview.dart';
import 'package:khuta/features/settings/widgets/calendar_settings.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, this.date, this.embedded = false});

  final DateTime? date;
  final bool embedded;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late DateTime _date = (widget.date ?? AppClock.today()).atMidnight;

  void _move(int days) => setState(() {
        _date = _date.add(Duration(days: days));
      });

  void _edit({
    JournalEntry? entry,
    required JournalEntryKind kind,
  }) {
    AppNavigator.push(
      JournalEntryEditorPage(
        date: _date.dayKey,
        kind: kind,
        entry: entry,
      ),
      fullscreenDialog: true,
    );
  }

  Future<void> _remove(JournalEntry entry) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.delete,
      message: entry.text,
      confirmLabel: context.l10n.delete,
      icon: LucideIcons.trash2,
    );
    if (confirmed == true && mounted) {
      await context.read<JournalController>().remove(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalController>();
    final habits = context.watch<HabitsController>();
    final focus = context.watch<FocusController>();
    final todos = context.watch<TodosController>();
    final settings = context.watch<SettingsController>();
    final minimal = settings.isMinimalStyle;
    final express = settings.isExpressStyle;
    final entries = journal.forDay(_date.dayKey);
    final reflection = journal.reflectionForDay(_date.dayKey);
    final activity = JournalProjection.forDay(
      day: _date,
      habits: habits,
      focus: focus,
      todos: todos,
    );
    final timeline = <_JournalTimelineItem>[
      for (final entry in entries) _JournalTimelineItem.forEntry(entry),
      for (final item in activity) _JournalTimelineItem.forActivity(item),
    ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: minimal ? 52 : null,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(LucideIcons.arrowLeftDir),
                onPressed: AppNavigator.pop,
              ),
        title: minimal || express ? null : Text(context.l10n.journal),
        actions: [
          IconButton(
            tooltip: context.l10n.journal_calendar,
            icon: const Icon(LucideIcons.calendarDays),
            onPressed: () => AppNavigator.push(
              JournalCalendarPage(selected: _date),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: context.pagePadding(
          minimal ? 20 : ClassicLayout.screenPadding,
          4,
          minimal ? 20 : ClassicLayout.screenPadding,
          widget.embedded ? ClassicLayout.bottomNavigationClearance : 36,
        ),
        children: [
          if (minimal || express)
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => _move(-1),
                  icon: const Icon(LucideIcons.chevronLeftDir),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _date.dayKey == AppClock.today().dayKey
                            ? context.l10n.journal_today
                            : DateFormat.EEEE(locale).format(_date),
                        style: TextStyle(
                          fontSize: minimal ? 25 : 22,
                          fontWeight: FontWeight.w900,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.calendarDay(_date, DateFormat.yMMMMd(locale).format(_date)),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: !_date.isBefore(AppClock.today())
                      ? null
                      : () => _move(1),
                  icon: const Icon(LucideIcons.chevronRightDir),
                ),
              ],
            )
          else
            ClassicDateNavigator(
              title: _date.dayKey == AppClock.today().dayKey
                  ? context.l10n.journal_today
                  : DateFormat.EEEE(locale).format(_date),
              subtitle: context.calendarDay(_date, DateFormat.yMMMMd(locale).format(_date)),
              onPrevious: () => _move(-1),
              onNext: !_date.isBefore(AppClock.today())
                  ? null
                  : () => _move(1),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _edit(kind: JournalEntryKind.moment),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text(context.l10n.journal_add_moment),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reflection == null
                      ? () => _edit(kind: JournalEntryKind.reflection)
                      : () => _edit(
                            entry: reflection,
                            kind: JournalEntryKind.reflection,
                          ),
                  icon: Icon(
                    reflection == null
                        ? LucideIcons.sparkles
                        : LucideIcons.pencil,
                    size: 18,
                  ),
                  label: Text(context.l10n.journal_daily_reflection),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: context.colors.surfaceContainerHighest
                        .withValues(alpha: 0.22),
                    side: BorderSide(
                      color: context.colors.outlineVariant.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: 24),
            for (final item in timeline) ...[
              _TimelineRow(
                occurredAt: item.occurredAt,
                child: item.entry != null
                    ? _EntryCard(
                        entry: item.entry!,
                        onTap: () => _edit(
                          entry: item.entry!,
                          kind: item.entry!.kind,
                        ),
                        onDelete: () => _remove(item.entry!),
                      )
                    : _ActivityCard(item: item.activity!),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (timeline.isEmpty) ...[
            const SizedBox(height: 70),
            Icon(
              LucideIcons.bookOpenText,
              size: 42,
              color: context.tokens.muted,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.journal_empty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.journal_empty_sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.4,
                color: context.tokens.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JournalTimelineItem {
  const _JournalTimelineItem._({
    required this.occurredAt,
    this.entry,
    this.activity,
  });

  factory _JournalTimelineItem.forEntry(JournalEntry entry) {
    final day = parseDayKey(entry.date);
    final occurredAt = entry.minutes == null
        ? entry.createdAt.toLocal()
        : day.add(Duration(minutes: entry.minutes!));
    return _JournalTimelineItem._(
      occurredAt: occurredAt,
      entry: entry,
    );
  }

  factory _JournalTimelineItem.forActivity(JournalActivity activity) =>
      _JournalTimelineItem._(
        occurredAt: activity.occurredAt.toLocal(),
        activity: activity,
      );

  final DateTime occurredAt;
  final JournalEntry? entry;
  final JournalActivity? activity;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.occurredAt,
    required this.child,
  });

  final DateTime occurredAt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(occurredAt).format(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.tokens.muted,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = entry.kind == JournalEntryKind.reflection
        ? context.l10n.journal_reflection
        : context.l10n.journal_moment;
    return Material(
      color: context.colors.surfaceContainerHighest.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(ClassicLayout.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ClassicLayout.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.kind == JournalEntryKind.reflection
                    ? LucideIcons.sparkles
                    : LucideIcons.messageCircle,
                size: 18,
                color: context.colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (entry.text.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      AutoDirectionText(
                        entry.text,
                        style: const TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ],
                    if (entry.photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PhotoDeck(
                        shots: [
                          for (final path in entry.photos) PhotoShot(path: path),
                        ],
                        size: 62,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  LucideIcons.ellipsis,
                  size: 19,
                  color: context.tokens.muted,
                ),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: context.tokens.danger,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.l10n.delete,
                          style: TextStyle(color: context.tokens.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, String title, String subtitle}) _activityPresentation(
  BuildContext context,
  JournalActivity item,
) =>
    switch (item.type) {
      'focus' => (
          icon: LucideIcons.timer,
          title: item.habitName.isEmpty ? context.l10n.focus : item.habitName,
          subtitle: context.l10n.minutes_short(
            '${((item.seconds ?? 0) / 60).round()}',
          ),
        ),
      'journey_milestone' => (
          icon: LucideIcons.flag,
          title: item.journeyTitle,
          subtitle: item.milestoneTitle,
        ),
      'todo_completed' => (
          icon: LucideIcons.listChecks,
          title: item.todoTitle,
          subtitle: context.l10n.todos,
        ),
      _ => (
          icon: LucideIcons.circleCheck,
          title:
              item.habitName.isEmpty ? context.l10n.your_habits : item.habitName,
          subtitle: item.amount == null ? '' : '${item.amount}',
        ),
    };

bool _activitySourceAvailable(BuildContext context, JournalActivity item) {
  switch (item.type) {
    case 'habit_completion':
      return item.habitId.isNotEmpty &&
          context.read<HabitsController>().byId(item.habitId) != null;
    case 'focus':
      final sessionId = item.id.startsWith('focus:') ? item.id.substring(6) : '';
      return sessionId.isNotEmpty &&
          context
              .read<FocusController>()
              .sessions
              .any((session) => session.id == sessionId);
    case 'todo_completed':
      return item.todoId.isNotEmpty &&
          context.read<TodosController>().all.any(
                (todo) => todo.id == item.todoId,
              );
    default:
      return false;
  }
}

String _activitySourceLabel(BuildContext context, JournalActivity item) {
  switch (item.type) {
    case 'habit_completion':
      return item.habitName.isEmpty ? context.l10n.your_habits : item.habitName;
    case 'focus':
      return context.l10n.focus_history;
    case 'todo_completed':
      return context.l10n.todos;
    default:
      return '';
  }
}

Future<void> _openActivitySource(
  BuildContext context,
  JournalActivity item,
) async {
  switch (item.type) {
    case 'habit_completion':
      final habit = context.read<HabitsController>().byId(item.habitId);
      if (habit == null) return;
      await AppNavigator.push(HabitDetailsPage(habitId: habit.id));
      return;
    case 'focus':
      final sessionId = item.id.startsWith('focus:') ? item.id.substring(6) : '';
      final session = context
          .read<FocusController>()
          .sessions
          .where((candidate) => candidate.id == sessionId)
          .firstOrNull;
      if (session == null) return;
      final linkedHabit = item.habitId.isEmpty
          ? null
          : context.read<HabitsController>().byId(item.habitId);
      await AppNavigator.push(
        FocusHistoryPage(
          habitId: linkedHabit?.id,
        ),
      );
      return;
    case 'todo_completed':
      final todos = context.read<TodosController>();
      final todo = todos.all
          .where((candidate) => candidate.id == item.todoId)
          .firstOrNull;
      if (todo == null) return;
      final action = await showTodoPreview(context, todo);
      if (!context.mounted || action == null) return;
      final fresh = todos.all
          .where((candidate) => candidate.id == item.todoId)
          .firstOrNull;
      if (fresh == null) return;
      if (action == 'edit') {
        await showTodoComposer(context, todo: fresh);
        return;
      }
      if (action == 'delete') {
        final confirmed = await showDeleteSheet(context);
        if (confirmed && context.mounted) {
          await context.read<TodosController>().remove(fresh.id);
        }
      }
      return;
  }
}

Future<void> _showActivityDetails(
  BuildContext context,
  JournalActivity item,
) async {
  final sourceAvailable = _activitySourceAvailable(context, item);
  final openSource = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ActivityDetailsSheet(
      item: item,
      sourceLabel:
          sourceAvailable ? _activitySourceLabel(sheetContext, item) : null,
    ),
  );

  if (openSource != true || !context.mounted) return;
  await _openActivitySource(context, item);
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});

  final JournalActivity item;

  @override
  Widget build(BuildContext context) {
    final (:icon, :title, :subtitle) = _activityPresentation(context, item);
    final radius = BorderRadius.circular(ClassicLayout.compactCardRadius);

    return Material(
      key: ValueKey('journal-activity-${item.id}'),
      color: context.colors.surfaceContainerHighest.withValues(alpha: 0.36),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => _showActivityDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 17, color: context.tokens.muted),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoDirectionText(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      AutoDirectionText(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.tokens.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRightDir,
                size: 16,
                color: context.tokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityDetailsSheet extends StatelessWidget {
  const _ActivityDetailsSheet({
    required this.item,
    required this.sourceLabel,
  });

  final JournalActivity item;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final (:icon, :title, :subtitle) = _activityPresentation(context, item);
    final local = item.occurredAt.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final date = context.calendarDay(local, DateFormat.yMMMMd(locale).format(local));
    final time = TimeOfDay.fromDateTime(local).format(context);

    return SafeArea(
      key: const Key('journal_activity_details'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ClassicLayout.screenPadding,
          4,
          ClassicLayout.screenPadding,
          ClassicLayout.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 20, color: context.colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AutoDirectionText(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$date · $time',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.tokens.muted,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 12),
              AutoDirectionText(
                subtitle,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ],
            if (sourceLabel != null && sourceLabel!.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('journal_activity_source_action'),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                label: AutoDirectionText(
                  sourceLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
