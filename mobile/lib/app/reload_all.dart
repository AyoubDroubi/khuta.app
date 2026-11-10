import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:khuta/features/daily_plan/state/daily_plan_controller.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';
import 'package:khuta/features/habits/state/categories_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/habits/state/notes_controller.dart';
import 'package:khuta/features/island/state/island_controller.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/todos/state/todo_tags_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

/// Re-reads every controller from the local store, after something wrote to
/// the store behind their back (a backup import, a folder pull).
Future<void> reloadAllFromStore(BuildContext context) async {
  final habits = context.read<HabitsController>();
  final settings = context.read<SettingsController>();
  await habits.reload();
  if (!context.mounted) return;
  context.read<NotesController>().reload();
  context.read<FocusController>().reload(restoreActive: true);
  context.read<TodosController>().reload();
  context.read<TodoTagsController>().reload();
  context.read<CategoriesController>().reload();
  context.read<DailyPlanController>().reload();
  context.read<IslandController>().reload();
  context.read<JournalController>().reload();
  context.read<JourneysController>().reload();
  context.read<GoalsController>().reload();
  await settings.reloadFromStore();
}
