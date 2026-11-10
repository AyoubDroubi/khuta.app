import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/goals/data/goal_progress.dart';
import 'package:khuta/features/goals/pages/goal_form_page.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journeys/pages/journey_detail_page.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

class GoalDetailPage extends StatelessWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();
    final goal = goals.byId(goalId);
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.goal_unavailable)),
      );
    }

    final habits = context.watch<HabitsController>();
    final todos = context.watch<TodosController>();
    final journeys = context.watch<JourneysController>();
    final hasChildren = goals.all.any(
      (candidate) => candidate.parentGoalId == goal.id,
    );
    final progress = GoalProgressCalculator.calculate(
      goalId: goal.id,
      goals: goals.all,
      habits: {for (final habit in habits.all) habit.id: habit},
      todos: {for (final todo in todos.all) todo.id: todo},
      journeys: {for (final journey in journeys.all) journey.id: journey},
      through: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            tooltip: context.l10n.goal_edit,
            icon: const Icon(LucideIcons.pencil),
            onPressed: () => AppNavigator.push(
              GoalFormPage(goalId: goal.id),
              fullscreenDialog: true,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          if (goal.description.isNotEmpty) ...[
            Text(
              goal.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(_state(context, goal.state))),
              if (goal.targetDate.isNotEmpty)
                Chip(
                  avatar: const Icon(LucideIcons.calendarDays, size: 16),
                  label: Text(goal.targetDate),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.goal_progress,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (progress.isEmpty)
            Text(context.l10n.goal_progress_empty)
          else
            for (final entry in progress.entries)
              _ProgressCard(type: entry.key, progress: entry.value),
          const SizedBox(height: 20),
          Text(
            context.l10n.goal_link_sources,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (goal.sources.isEmpty)
            Text(context.l10n.goal_no_sources)
          else
            for (final source in goal.sources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_sourceIcon(source.type)),
                title: Text(
                  source.sourceTitle.isEmpty
                      ? context.l10n.goal_source_unavailable
                      : source.sourceTitle,
                ),
                subtitle: source.available
                    ? Text(_sourceLabel(context, source.type))
                    : Text(context.l10n.goal_source_unavailable),
                trailing: source.available
                    ? const Icon(LucideIcons.chevronRightDir)
                    : const Icon(LucideIcons.circleAlert),
                onTap: source.available
                    ? () => _openSource(source)
                    : null,
              ),
          if (goals.childrenOf(goal.id).isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              context.l10n.goal_subgoals,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final child in goals.childrenOf(goal.id))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.cornerDownRight),
                title: Text(child.title),
                trailing: const Icon(LucideIcons.chevronRightDir),
                onTap: () => AppNavigator.push(
                  GoalDetailPage(goalId: child.id),
                ),
              ),
          ],
          const SizedBox(height: 20),
          if (goal.state != GoalState.completed)
            FilledButton.icon(
              onPressed: () =>
                  goals.setState(goal.id, GoalState.completed),
              icon: const Icon(LucideIcons.circleCheckBig),
              label: Text(context.l10n.goal_mark_completed),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => goals.setState(
              goal.id,
              goal.isArchived ? GoalState.active : GoalState.archived,
            ),
            icon: const Icon(LucideIcons.archive),
            label: Text(
              goal.isArchived
                  ? context.l10n.goal_restore
                  : context.l10n.goal_archive,
            ),
          ),
          if (!hasChildren) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _deleteGoal(context, goals, goal),
              icon: const Icon(LucideIcons.trash2),
              label: Text(context.l10n.delete),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _deleteGoal(
    BuildContext context,
    GoalsController goals,
    Goal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(goal.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await goals.remove(goal.id);
    if (context.mounted) {
      AppNavigator.pop();
    }
  }

  static IconData _sourceIcon(GoalSourceType type) => switch (type) {
        GoalSourceType.habit => LucideIcons.repeat2,
        GoalSourceType.todo => LucideIcons.listChecks,
        GoalSourceType.journey => LucideIcons.route,
      };

  static String _sourceLabel(BuildContext context, GoalSourceType type) =>
      switch (type) {
        GoalSourceType.habit => context.l10n.goal_source_habits,
        GoalSourceType.todo => context.l10n.todos,
        GoalSourceType.journey => context.l10n.journeys,
      };

  static String _state(BuildContext context, GoalState state) => switch (state) {
        GoalState.active => context.l10n.goal_active,
        GoalState.completed => context.l10n.goal_completed,
        GoalState.archived => context.l10n.goal_archived,
      };

  static void _openSource(GoalSourceLink source) {
    switch (source.type) {
      case GoalSourceType.habit:
        AppNavigator.push(HabitDetailsPage(habitId: source.sourceId));
        return;
      case GoalSourceType.journey:
        AppNavigator.push(JourneyDetailPage(journeyId: source.sourceId));
        return;
      case GoalSourceType.todo:
        return;
    }
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.type, required this.progress});

  final GoalSourceType type;
  final GoalTypeProgress progress;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      GoalSourceType.habit => context.l10n.goal_source_habits,
      GoalSourceType.todo => context.l10n.todos,
      GoalSourceType.journey => context.l10n.journeys,
    };
    final fraction = progress.target <= 0
        ? 0.0
        : (progress.actual / progress.target).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text('${progress.percent.round()}%'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 6),
            Text(context.l10n.goal_sources_count(progress.sourceCount)),
          ],
        ),
      ),
    );
  }
}
