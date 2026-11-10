import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/goals/pages/goals_page.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';

class GoalsEntryCard extends StatelessWidget {
  const GoalsEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();
    final activeCount =
        goals.all.where((goal) => !goal.isArchived).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('statistics-goals-entry'),
        leading: const Icon(LucideIcons.target),
        title: Text(context.l10n.goals),
        subtitle: Text(
          activeCount == 0
              ? context.l10n.goals_entry_empty
              : context.l10n.goals_entry_count(activeCount),
        ),
        trailing: const Icon(LucideIcons.chevronRightDir),
        onTap: () => AppNavigator.push(const GoalsPage()),
      ),
    );
  }
}
