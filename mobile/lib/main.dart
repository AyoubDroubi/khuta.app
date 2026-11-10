import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/digits.dart';
import 'package:khuta/app/startup_failure.dart';
import 'package:khuta/app/khuta_app.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/utils/app_dirs.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/focus/pages/focus_page.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';
import 'package:khuta/features/focus/state/focus_actions.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/daily_plan/state/daily_plan_controller.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/state/categories_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/island/state/island_controller.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/habits/state/notes_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';
import 'package:khuta/features/todos/pages/todos_page.dart';
import 'package:khuta/features/todos/state/todo_tags_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:khuta/services/focus_service.dart';
import 'package:khuta/services/home_widget_service.dart';
import 'package:khuta/services/notification_service.dart';
import 'package:khuta/services/todos_widget_service.dart';
import 'package:khuta/services/widget_action_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  useWesternDigits();
  try {
    await _startup();
  } catch (e, s) {
    debugPrint('Khuta could not start: $e');
    debugPrintStack(stackTrace: s);
    runApp(StartupFailure(error: '$e', logPath: _writeStartupLog(e, s)));
    return;
  }
  _run();
}

String? _writeStartupLog(Object error, StackTrace stack) {
  if (isMobile) return null;
  try {
    final file = File('${Directory.systemTemp.path}/streak_startup_error.txt');
    file.writeAsStringSync('${DateTime.now()}\n$error\n\n$stack');
    return file.path;
  } catch (_) {
    return null;
  }
}

Future<void> _startup() async {
  if (isMobile) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  await initializeDateFormatting();
  await LocalStore.init();
  AppClock.cutoffHour = LocalStore.setting('dayCutoff', 0);

  NotificationService.onOpenHabit = _openHabit;
  NotificationService.onOpenTodos = _openTodos;
  FocusService.onPending = drainFocusActions;
  FocusService.listen();
  try {
    await NotificationService().initialize();
  } catch (e, s) {
    debugPrint('Startup init (notifications/widget) failed: $e\n$s');
  }

  _appChannel.setMethodCallHandler((call) async {
    if (call.method == 'openHabit') {
      final id = call.arguments as String?;
      if (id != null) _openHabit(id);
    }
    if (call.method == 'startFocus') {
      final id = call.arguments as String?;
      if (id != null) _startFocus(id);
    }
    if (call.method == 'openPage') {
      final page = call.arguments as String?;
      if (page != null) _openPage(page);
    }
    return null;
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final pending = NotificationService().pendingHabitId;
    if (pending != null) {
      NotificationService().pendingHabitId = null;
      _openHabit(pending);
    }
    if (isMobile) {
      final launched =
          await _appChannel.invokeMethod<String>('consumeLaunchHabit');
      if (launched != null) _openHabit(launched);
      final focusOn = await _appChannel.invokeMethod<String>('consumeLaunchFocus');
      if (focusOn != null) _startFocus(focusOn);
      final page = await _appChannel.invokeMethod<String>('consumeLaunchPage');
      if (page != null) _openPage(page);
    }
  });
}

void _run() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => CategoriesController()),
        ChangeNotifierProvider(create: (_) => TodoTagsController()),
        ChangeNotifierProvider(create: (_) => NotesController()),
        ChangeNotifierProvider(create: (_) => TodosController()),
        ChangeNotifierProvider(
          create: (_) => FocusController(restoreOnCreate: false),
        ),
        ChangeNotifierProvider(create: (_) => DailyPlanController()),
        ChangeNotifierProvider(create: (_) => IslandController()),
        ChangeNotifierProvider(create: (_) => JourneysController()),
        ChangeNotifierProvider(create: (_) => GoalsController()),
        ChangeNotifierProvider(create: (_) => JournalController()),
        ChangeNotifierProvider(create: (_) => HabitsController()),
      ],
      child: const KhutaApp(),
    ),
  );
}

const _appChannel = MethodChannel('khuta/app_icon');

void _openHabit(String habitId) {
  AppNavigator.push(HabitDetailsPage(habitId: habitId), fade: true);
}

void _openTodos() {
  AppNavigator.push(const TodosPage(), fade: true);
}

void _openPage(String page) {
  if (page == 'todos') _openTodos();
  if (page == 'stats') AppNavigator.push(const StatisticsPage(), fade: true);
}

void _startFocus(String habitId) {
  final context = AppNavigator.key.currentContext;
  if (context == null) return;
  if (AppNavigator.isShowing(FocusPage.routeName)) return;
  if (context.read<FocusController>().isActive) {
    AppNavigator.push(const FocusPage(), fade: true, name: FocusPage.routeName);
    return;
  }
  final habit = context.read<HabitsController>().byId(habitId);
  if (habit == null) return;
  AppNavigator.push(
    FocusPage(
      startHabitId: habit.id,
      startMinutes: habit.focusMinutes,
      breakMinutes: habit.focusBreakMinutes,
    ),
    fade: true,
    name: FocusPage.routeName,
  );
}

@pragma('vm:entry-point')
Future<void> widgetActionEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  useWesternDigits();
  const channel = MethodChannel('khuta/widget_action');
  try {
    await initializeDateFormatting();
    await LocalStore.init();
    AppClock.cutoffHour = LocalStore.setting('dayCutoff', 0);
    await LocalStore.reloadHabits();
    final habits = LocalStore.readHabits();
    final todos = LocalStore.readTodos();
    await WidgetActionService.drain(habits, todos: todos);
    await HomeWidgetService.sync(habits, renderIcons: false);
    await TodosWidgetService.sync(todos);
    await NotificationService().rescheduleTodos(todos);
  } catch (e) {
    debugPrint('Widget action entrypoint failed: $e');
  }
  await channel.invokeMethod('done');
}
