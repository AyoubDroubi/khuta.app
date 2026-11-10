import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/daily_plan/state/daily_plan_controller.dart';
import 'package:khuta/features/daily_plan/data/daily_plan_completion.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

class DailyPlanCard extends StatelessWidget {
  const DailyPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DailyPlanController>();
    final habits = context.watch<HabitsController>();
    final todos = context.watch<TodosController>();
    final journeys = context.watch<JourneysController>();
    final settings = context.watch<SettingsController>();
    final day = AppClock.today();
    final plan = controller.forDate(day);
    final resolved = [
      for (final item in plan.items)
        _resolve(context, item, day, habits, todos, journeys),
    ];
    final outcome = DailyPlanCompletion.outcomeFor(
      plan,
      day,
      habits: habits.habits,
      todos: todos.all,
      journeys: journeys.all,
    );
    final radius = settings.isExpressStyle
        ? 28.0
        : settings.isMinimalStyle
            ? 18.0
            : 24.0;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(15, 13, 12, 13),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: context.colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.listTodo,
                  size: 18,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.daily_plan_title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      plan.items.isEmpty
                          ? context.l10n.daily_plan_limit
                          : context.l10n.daily_plan_progress(
                              outcome.completedCount,
                              outcome.plannedCount,
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: plan.items.isEmpty
                    ? context.l10n.daily_plan_add
                    : context.l10n.daily_plan_edit,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  plan.items.isEmpty ? LucideIcons.plus : LucideIcons.pencil,
                  size: 18,
                ),
                onPressed: () => showDailyPlanEditor(context),
              ),
            ],
          ),
          if (plan.items.isEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => showDailyPlanEditor(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.circlePlus,
                      size: 18,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        context.l10n.daily_plan_empty,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          color: context.tokens.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (var index = 0; index < resolved.length; index++) ...[
              _PriorityRow(item: resolved[index]),
              if (index != resolved.length - 1)
                Divider(
                  height: 12,
                  color: context.colors.outlineVariant.withValues(alpha: 0.45),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

Future<void> showDailyPlanEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _DailyPlanEditor(),
    );

class _DailyPlanEditor extends StatelessWidget {
  const _DailyPlanEditor();

  @override
  Widget build(BuildContext context) {
    final planController = context.watch<DailyPlanController>();
    final habits = context.watch<HabitsController>();
    final todos = context.watch<TodosController>();
    final journeys = context.watch<JourneysController>();
    final day = AppClock.today();
    final plan = planController.forDate(day);
    final selected = plan.items.map((item) => item.key).toSet();
    final full = plan.items.length >= DailyPlan.maxItems;

    final habitOptions = habits.habits
        .where((habit) => !habit.isArchived)
        .map(
          (habit) => _Option(
            item: DailyPlanItem(
              type: DailyPlanSourceType.habit,
              sourceId: habit.id,
            ),
            title: habit.name,
            subtitle: context.l10n.daily_plan_habit,
            icon: LucideIcons.target,
          ),
        )
        .where((option) => !selected.contains(option.item.key))
        .toList(growable: false);

    final todoOptions = todos.all
        .where((todo) => !todo.done)
        .map(
          (todo) => _Option(
            item: DailyPlanItem(
              type: DailyPlanSourceType.todo,
              sourceId: todo.id,
            ),
            title: todo.title,
            subtitle: context.l10n.daily_plan_todo,
            icon: LucideIcons.squareCheckBig,
          ),
        )
        .where((option) => !selected.contains(option.item.key))
        .toList(growable: false);

    final milestoneOptions = <_Option>[];
    for (final journey in journeys.all) {
      if (journey.status == JourneyStatus.archived) continue;
      for (final milestone in journey.milestones) {
        if (milestone.completed) continue;
        final item = DailyPlanItem(
          type: DailyPlanSourceType.journeyMilestone,
          sourceId: journey.id,
          milestoneId: milestone.id,
        );
        if (selected.contains(item.key)) continue;
        milestoneOptions.add(
          _Option(
            item: item,
            title: milestone.title,
            subtitle: journey.title,
            icon: LucideIcons.flag,
          ),
        );
      }
    }

    final noOptions =
        habitOptions.isEmpty && todoOptions.isEmpty && milestoneOptions.isEmpty;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.daily_plan_title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${plan.items.length}/${DailyPlan.maxItems}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.tokens.muted,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                if (plan.items.isNotEmpty) ...[
                  for (var index = 0; index < plan.items.length; index++)
                    _SelectedRow(
                      resolved: _resolve(
                        context,
                        plan.items[index],
                        day,
                        habits,
                        todos,
                        journeys,
                      ),
                      onUp: index == 0
                          ? null
                          : () => planController.move(day, index, index - 1),
                      onDown: index == plan.items.length - 1
                          ? null
                          : () => planController.move(day, index, index + 1),
                      onRemove: () => planController.remove(
                        day,
                        plan.items[index].key,
                      ),
                    ),
                  const SizedBox(height: 18),
                ],
                if (!full && habitOptions.isNotEmpty)
                  _OptionSection(
                    title: context.l10n.active_habits,
                    options: habitOptions,
                    onAdd: (item) => planController.add(day, item),
                  ),
                if (!full && todoOptions.isNotEmpty)
                  _OptionSection(
                    title: context.l10n.todos,
                    options: todoOptions,
                    onAdd: (item) => planController.add(day, item),
                  ),
                if (!full && milestoneOptions.isNotEmpty)
                  _OptionSection(
                    title: context.l10n.daily_plan_milestones,
                    options: milestoneOptions,
                    onAdd: (item) => planController.add(day, item),
                  ),
                if (full)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      context.l10n.daily_plan_limit,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.tokens.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (noOptions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      context.l10n.daily_plan_no_sources,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.tokens.muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.item});

  final _ResolvedPriority item;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: item.completed
                  ? context.colors.primary
                  : context.colors.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: item.completed
                    ? context.colors.primary
                    : context.colors.outlineVariant,
              ),
            ),
            child: Icon(
              item.completed ? LucideIcons.check : item.icon,
              size: 14,
              color: item.completed
                  ? context.colors.onPrimary
                  : context.tokens.muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    decoration:
                        item.completed ? TextDecoration.lineThrough : null,
                    color: item.missing
                        ? context.tokens.muted
                        : context.colors.onSurface,
                  ),
                ),
                if (item.subtitle.isNotEmpty)
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.tokens.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class _SelectedRow extends StatelessWidget {
  const _SelectedRow({
    required this.resolved,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final _ResolvedPriority resolved;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(resolved.icon, size: 18, color: context.colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                resolved.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onUp,
              icon: const Icon(LucideIcons.chevronUp, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDown,
              icon: const Icon(LucideIcons.chevronDown, size: 18),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(
                LucideIcons.x,
                size: 18,
                color: context.tokens.danger,
              ),
            ),
          ],
        ),
      );
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.title,
    required this.options,
    required this.onAdd,
  });

  final String title;
  final List<_Option> options;
  final ValueChanged<DailyPlanItem> onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.tokens.muted,
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(option.icon, size: 19),
                title: Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: option.subtitle.isEmpty
                    ? null
                    : Text(
                        option.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: const Icon(LucideIcons.plus, size: 18),
                onTap: () => onAdd(option.item),
              ),
          ],
        ),
      );
}

class _Option {
  const _Option({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final DailyPlanItem item;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ResolvedPriority {
  const _ResolvedPriority({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
    this.missing = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final bool missing;
}

_ResolvedPriority _resolve(
  BuildContext context,
  DailyPlanItem item,
  DateTime day,
  HabitsController habits,
  TodosController todos,
  JourneysController journeys,
) {
  switch (item.type) {
    case DailyPlanSourceType.habit:
      final habit = habits.byId(item.sourceId);
      if (habit == null) return _missing(context, LucideIcons.target);
      return _ResolvedPriority(
        title: habit.name,
        subtitle: context.l10n.daily_plan_habit,
        icon: LucideIcons.target,
        completed: DailyPlanCompletion.habitCompletedOn(habit, day),
      );

    case DailyPlanSourceType.todo:
      Todo? todo;
      for (final candidate in todos.all) {
        if (candidate.id == item.sourceId) {
          todo = candidate;
          break;
        }
      }
      if (todo == null) return _missing(context, LucideIcons.squareCheckBig);
      return _ResolvedPriority(
        title: todo.title,
        subtitle: context.l10n.daily_plan_todo,
        icon: LucideIcons.squareCheckBig,
        completed: DailyPlanCompletion.todoCompletedOn(todo, day),
      );

    case DailyPlanSourceType.journeyMilestone:
      final journey = journeys.byId(item.sourceId);
      JourneyMilestone? milestone;
      if (journey != null) {
        for (final candidate in journey.milestones) {
          if (candidate.id == item.milestoneId) {
            milestone = candidate;
            break;
          }
        }
      }
      if (journey == null || milestone == null) {
        return _missing(context, LucideIcons.flag);
      }
      return _ResolvedPriority(
        title: milestone.title,
        subtitle: journey.title,
        icon: LucideIcons.flag,
        completed: DailyPlanCompletion.milestoneCompletedOn(milestone, day),
      );
  }
}

_ResolvedPriority _missing(BuildContext context, IconData icon) =>
    _ResolvedPriority(
      title: context.l10n.daily_plan_source_missing,
      subtitle: '',
      icon: icon,
      completed: false,
      missing: true,
    );
