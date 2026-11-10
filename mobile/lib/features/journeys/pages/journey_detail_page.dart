import 'dart:io';

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
import 'package:khuta/core/widgets/app_empty_state.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/data/journal_projection.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/journeys/pages/journey_form_page.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

class JourneyDetailPage extends StatelessWidget {
  const JourneyDetailPage({
    super.key,
    required this.journeyId,
  });

  final String journeyId;

  String _status(BuildContext context, JourneyStatus status) => switch (status) {
        JourneyStatus.planned => context.l10n.journey_planned,
        JourneyStatus.active => context.l10n.journey_active,
        JourneyStatus.completed => context.l10n.journey_completed,
        JourneyStatus.archived => context.l10n.journey_archived,
      };

  Future<void> _delete(
    BuildContext context,
    Journey journey,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.delete,
      message: journey.title,
      confirmLabel: context.l10n.delete,
      icon: LucideIcons.trash2,
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<JourneysController>().remove(journey.id);
    if (context.mounted) AppNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<JourneysController>();
    final journey = controller.byId(journeyId);
    final settings = context.watch<SettingsController>();
    final minimal = settings.isMinimalStyle;

    if (journey == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(LucideIcons.arrowLeftDir),
            onPressed: AppNavigator.pop,
          ),
        ),
        body: AppEmptyState(
          icon: LucideIcons.route,
          title: context.l10n.journey_no_items,
        ),
      );
    }

    final habits = context.watch<HabitsController>();
    final focus = context.watch<FocusController>();
    final timeline = JournalProjection.forJourney(
      journey: journey,
      habits: habits,
      focus: focus,
    );
    final linkedHabits = journey.habitIds
        .map(habits.byId)
        .whereType<Habit>()
        .toList(growable: false);
    final completed =
        journey.milestones.where((item) => item.completed).length;
    final total = journey.milestones.length;
    final hasCover =
        journey.coverPath.isNotEmpty && File(journey.coverPath).existsSync();
    final start = JournalProjection.parseDayKeyOrNull(journey.startDate);
    final linkedIds = journey.habitIds.toSet();
    final focusSeconds = focus.sessions
        .where(
          (session) =>
              linkedIds.contains(session.habitId) &&
              (start == null ||
                  !session.startedAt.atMidnight.isBefore(start.atMidnight)),
        )
        .fold<int>(0, (sum, session) => sum + session.seconds);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: minimal ? 52 : null,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.arrowLeftDir),
          onPressed: AppNavigator.pop,
        ),
        title: minimal ? null : Text(journey.title),
        actions: [
          IconButton(
            tooltip: context.l10n.edit,
            icon: const Icon(LucideIcons.pencil, size: 19),
            onPressed: () => AppNavigator.push(
              JourneyFormPage(journey: journey),
              fullscreenDialog: true,
            ),
          ),
          IconButton(
            tooltip: context.l10n.delete,
            icon: const Icon(LucideIcons.trash2, size: 19),
            onPressed: () => _delete(context, journey),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: context.pagePadding(
          minimal ? 20 : 16,
          6,
          minimal ? 20 : 16,
          42,
        ),
        children: [
          if (hasCover)
            Container(
              height: 190,
              margin: const EdgeInsets.only(bottom: 20),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Image.file(File(journey.coverPath), fit: BoxFit.cover),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  LucideIcons.route,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.title,
                      style: TextStyle(
                        fontSize: minimal ? 28 : 24,
                        fontWeight: FontWeight.w900,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _status(context, journey.status),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (journey.description.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              journey.description,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: context.tokens.muted,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: journey.progress,
              minHeight: 9,
              backgroundColor:
                  context.colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.journey_progress(completed, total),
            style: TextStyle(
              fontSize: 12.5,
              color: context.tokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (journey.startDate.isNotEmpty ||
              journey.targetDate.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (journey.startDate.isNotEmpty)
                  _InfoChip(
                    icon: LucideIcons.play,
                    text: _formatDate(journey.startDate, locale),
                  ),
                if (journey.targetDate.isNotEmpty)
                  _InfoChip(
                    icon: LucideIcons.flag,
                    text: _formatDate(journey.targetDate, locale),
                  ),
              ],
            ),
          ],
          if (journey.focusTargetMinutes != null) ...[
            const SizedBox(height: 22),
            _SectionTitle(context.l10n.journey_focus_target),
            const SizedBox(height: 9),
            _FocusTarget(
              doneMinutes: (focusSeconds / 60).floor(),
              targetMinutes: journey.focusTargetMinutes!,
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(context.l10n.journey_milestones),
          const SizedBox(height: 9),
          if (journey.milestones.isEmpty)
            Text(
              context.l10n.no_data_yet,
              style: TextStyle(color: context.tokens.muted),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  for (final item in journey.milestones)
                    CheckboxListTile(
                      key: ValueKey(item.id),
                      value: item.completed,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        item.title,
                        style: TextStyle(
                          decoration: item.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      onChanged: (_) => controller.toggleMilestone(
                        journey.id,
                        item.id,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _SectionTitle(context.l10n.journey_linked_habits),
          const SizedBox(height: 9),
          if (linkedHabits.isEmpty)
            Text(
              context.l10n.no_habits_yet,
              style: TextStyle(color: context.tokens.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final habit in linkedHabits)
                  Chip(
                    avatar: Text(
                      habit.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                    label: Text(habit.name),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          _SectionTitle(context.l10n.journey_timeline),
          const SizedBox(height: 9),
          if (timeline.isEmpty)
            Text(
              context.l10n.no_data_yet,
              style: TextStyle(color: context.tokens.muted),
            )
          else
            for (final item in timeline) ...[
              _TimelineRow(item: item, locale: locale),
              const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }

  static String _formatDate(String dayKey, String locale) {
    final date = JournalProjection.parseDayKeyOrNull(dayKey);
    return date == null ? dayKey : DateFormat.yMMMd(locale).format(date);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.tokens.muted),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _FocusTarget extends StatelessWidget {
  const _FocusTarget({
    required this.doneMinutes,
    required this.targetMinutes,
  });

  final int doneMinutes;
  final int targetMinutes;

  @override
  Widget build(BuildContext context) {
    final safeTarget = targetMinutes <= 0 ? 1 : targetMinutes;
    final ratio = (doneMinutes / safeTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.timer, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.l10n.minutes_short('$doneMinutes'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                context.l10n.minutes_short('$targetMinutes'),
                style: TextStyle(color: context.tokens.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: ratio),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.locale,
  });

  final JournalActivity item;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final (:icon, :title, :subtitle) = switch (item.type) {
      'focus' => (
          icon: LucideIcons.timer,
          title: item.habitName.isEmpty ? context.l10n.focus : item.habitName,
          subtitle: context.l10n.minutes_short(
            '${((item.seconds ?? 0) / 60).round()}',
          ),
        ),
      'journey_milestone' => (
          icon: LucideIcons.flag,
          title: item.milestoneTitle,
          subtitle: item.journeyTitle,
        ),
      _ => (
          icon: LucideIcons.circleCheck,
          title: item.habitName,
          subtitle: item.amount == null ? '' : '${item.amount}',
        ),
    };

    final date = JournalProjection.parseDayKeyOrNull(item.date);
    final dateLabel =
        date == null ? item.date : DateFormat.yMMMd(locale).format(date);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: context.colors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
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
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 11,
              color: context.tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: context.colors.onSurface,
        ),
      );
}
