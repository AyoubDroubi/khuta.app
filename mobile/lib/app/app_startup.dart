import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khuta/features/daily_plan/state/daily_plan_controller.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/state/categories_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/app/reload_all.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/focus/state/focus_actions.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:khuta/services/folder_sync.dart';
import 'package:khuta/services/widget_action_service.dart';
import 'package:khuta/services/home_widget_service.dart';
import 'package:khuta/services/image_cleanup_service.dart';
import 'package:khuta/services/notification_service.dart';
import 'package:khuta/services/todos_widget_service.dart';

/// Work that has to happen once per launch, after the first frame: restore a
/// running focus session, re-arm reminders, refresh the home-screen widgets,
/// run the automatic local backup and clean unused images. (It replaces the
/// start-up part of the removed account gate.)
class AppStartup extends StatefulWidget {
  const AppStartup({required this.child, super.key});

  final Widget child;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    if (!mounted) return;
    final settings = context.read<SettingsController>();
    final focus = context.read<FocusController>();
    final dailyPlan = context.read<DailyPlanController>();
    final habits = context.read<HabitsController>();
    final todos = context.read<TodosController>();

    // First launch: reload() seeds the default categories when there are none.
    context.read<CategoriesController>().reload();
    focus.reload(restoreActive: true);
    dailyPlan.reload();

    // What the account gate used to do after sign-in: apply home-screen widget
    // and focus actions queued while the app was closed, and pull the shared
    // backup folder, then show the result.
    try {
      await WidgetActionService.drain(
        LocalStore.readHabits(),
        todos: LocalStore.readTodos(),
      );
      await LocalStore.guardWrites(FolderSync.pull);
      await drainFocusActions();
    } catch (e) {
      debugPrint('Start-up sync step failed: $e');
    }
    if (!mounted) return;
    await reloadAllFromStore(context);
    if (!mounted) return;

    unawaited(habits.rescheduleReminders());
    unawaited(habits.rescheduleRecovery());
    unawaited(settings.runAutoBackup());
    unawaited(ImageCleanupService.run());
    unawaited(HomeWidgetService.sync(habits.asMap));

    final allTodos = todos.all;
    unawaited(TodosWidgetService.sync(allTodos));
    unawaited(NotificationService().rescheduleTodos(allTodos));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
