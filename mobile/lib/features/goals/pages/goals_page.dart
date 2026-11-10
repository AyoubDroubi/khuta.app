import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/core/widgets/app_empty_state.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/goals/pages/goal_detail_page.dart';
import 'package:khuta/features/goals/pages/goal_form_page.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GoalsController>();
    final roots = controller.roots;
    final archived = controller.archived;
    final hasGoals = roots.isNotEmpty || archived.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.goals),
        actions: [
          IconButton(
            tooltip: context.l10n.goal_new,
            icon: const Icon(LucideIcons.plus),
            onPressed: () => AppNavigator.push(
              const GoalFormPage(),
              fullscreenDialog: true,
            ),
          ),
        ],
      ),
      body: !hasGoals
          ? AppEmptyState(
              icon: LucideIcons.target,
              title: context.l10n.goals_empty,
              message: context.l10n.goals_empty_sub,
              action: FilledButton.icon(
                onPressed: () => AppNavigator.push(
                  const GoalFormPage(),
                  fullscreenDialog: true,
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(context.l10n.goal_new),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                for (final root in roots)
                  ..._tree(context, controller, root, 0),
                if (archived.isNotEmpty) ...[
                  if (roots.isNotEmpty) const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.l10n.goal_archived,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final goal in archived)
                    _archivedTile(context, goal),
                ],
              ],
            ),
      floatingActionButton: !hasGoals
          ? null
          : FloatingActionButton(
              onPressed: () => AppNavigator.push(
                const GoalFormPage(),
                fullscreenDialog: true,
              ),
              child: const Icon(LucideIcons.plus),
            ),
    );
  }

  Widget _archivedTile(BuildContext context, Goal goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(LucideIcons.archive),
          title: Text(
            goal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(context.l10n.goal_archived),
          trailing: const Icon(LucideIcons.chevronRightDir),
          onTap: () => AppNavigator.push(
            GoalDetailPage(goalId: goal.id),
          ),
        ),
      ),
    );
  }

  List<Widget> _tree(
    BuildContext context,
    GoalsController controller,
    Goal goal,
    int depth,
  ) {
    final children = controller.childrenOf(goal.id);
    return [
      Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 18.0, bottom: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Icon(
              goal.state == GoalState.completed
                  ? LucideIcons.circleCheckBig
                  : LucideIcons.target,
            ),
            title: Text(
              goal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_stateLabel(context, goal.state)),
            trailing: children.isEmpty
                ? const Icon(LucideIcons.chevronRightDir)
                : Text('${children.length}'),
            onTap: () => AppNavigator.push(
              GoalDetailPage(goalId: goal.id),
            ),
          ),
        ),
      ),
      for (final child in children)
        ..._tree(context, controller, child, depth + 1),
    ];
  }

  String _stateLabel(BuildContext context, GoalState state) => switch (state) {
        GoalState.active => context.l10n.goal_active,
        GoalState.completed => context.l10n.goal_completed,
        GoalState.archived => context.l10n.goal_archived,
      };
}
