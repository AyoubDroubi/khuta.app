import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/digits.dart';
import 'package:khuta/app/theme/app_theme.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';
import 'package:khuta/features/daily_plan/state/daily_plan_controller.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit_note.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/substep.dart';
import 'package:khuta/features/habits/state/categories_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/habits/state/notes_controller.dart';
import 'package:khuta/features/island/state/island_controller.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/state/todo_tags_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:khuta/l10n/app_localizations.dart';

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _appUsage = MethodChannel('khuta/app_usage');

late Directory _storeDir;

void useEmptyStore() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useWesternDigits();

  setUp(() async {
    _storeDir = await Directory.systemTemp.createTemp('streak_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (call) async => _storeDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_appUsage, (call) async {
      switch (call.method) {
        case 'hasUsageAccess':
          return false;
        case 'openUsageAccessSettings':
          return true;
        case 'readToday':
          return {'totalDurationMs': 0, 'apps': <Object>[]};
        default:
          return null;
      }
    });
    await LocalStore.init();
  });

  tearDown(() async {
    await Hive.close().timeout(
      const Duration(seconds: 2),
      onTimeout: () => const <void>[],
    );
    try {
      _storeDir.deleteSync(recursive: true);
    } on FileSystemException {
      return;
    }
  });
}

Future<void> coldStart() async {
  await Hive.close();
  await LocalStore.init();
}

Habit testHabit({
  required String id,
  required String name,
  Color color = const Color(0xFF7C5CFF),
  int order = 0,
  HabitKind kind = HabitKind.positive,
  double perDayTarget = 1,
  String unitLabel = '',
  String category = '',
  List<DateTime> done = const [],
  int daysOld = 60,
  HabitInterval interval = HabitInterval.daily,
  List<int> scheduleWeekdays = const [],
  List<int> restDays = const [],
  int startMinute = -1,
  int durationMinutes = 0,
  bool focusOnly = false,
  List<Substep> substeps = const [],
}) =>
    Habit(
      id: id,
      name: name,
      color: color,
      order: order,
      kind: kind,
      perDayTarget: perDayTarget,
      unitLabel: unitLabel,
      category: category,
      interval: interval,
      scheduleWeekdays: scheduleWeekdays,
      restDays: restDays,
      startMinute: startMinute,
      durationMinutes: durationMinutes,
      focusOnly: focusOnly,
      substeps: substeps,
      createdAt: AppClock.now().subtract(Duration(days: daysOld)),
      completions: {
        for (final day in done)
          day.dayKey: Completion(
            date: day.dayKey,
            hour: 9,
            count: kind == HabitKind.quantitative ? perDayTarget : 1,
          ),
      },
    );

List<DateTime> lastDays(int count) {
  final today = AppClock.now();
  return List.generate(count, (i) => today.subtract(Duration(days: i)));
}

HabitNote testNote({
  required String id,
  required String habitId,
  required DateTime day,
  required String text,
  NoteType type = NoteType.note,
}) =>
    HabitNote(
      id: id,
      habitId: habitId,
      date: day.dayKey,
      type: type,
      text: text,
      createdAt: day,
    );

Future<void> seedNotes(WidgetTester tester, List<HabitNote> notes) =>
    tester.runAsync(() async {
      for (final note in notes) {
        await LocalStore.writeNote(note);
      }
    });

Todo testTodo({
  required String id,
  required String text,
  DateTime? due,
  int? minutes,
  TodoPriority priority = TodoPriority.none,
  bool done = false,
  DateTime? createdAt,
}) =>
    Todo(
      id: id,
      text: text,
      done: done,
      date: due?.dayKey ?? '',
      minutes: minutes,
      priority: priority,
      createdAt: createdAt ?? AppClock.now(),
      doneAt: done ? (createdAt ?? AppClock.now()) : null,
    );

Future<void> seedTodos(WidgetTester tester, List<Todo> todos) =>
    tester.runAsync(() async {
      for (final todo in todos) {
        await LocalStore.writeTodo(todo);
      }
    });

Future<void> seedHabits(WidgetTester tester, List<Habit> habits) =>
    tester.runAsync(() async {
      for (final habit in habits) {
        await LocalStore.writeHabit(habit);
      }
    });

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  bool minimal = false,
  Map<String, Object> settings = const {},
  ThemeMode themeMode = ThemeMode.dark,
  double textScale = 1,
  bool settle = true,
  Locale? locale,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await LocalStore.writeSetting('onboardingDone', true);
    await LocalStore.writeSetting('appStyle', minimal ? 1 : 0);
    for (final entry in settings.entries) {
      await LocalStore.writeSetting(entry.key, entry.value);
    }
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => CategoriesController()),
        ChangeNotifierProvider(create: (_) => NotesController()),
        ChangeNotifierProvider(create: (_) => TodosController()),
        ChangeNotifierProvider(create: (_) => TodoTagsController()),
        ChangeNotifierProvider(create: (_) => FocusController()),
        ChangeNotifierProvider(create: (_) => DailyPlanController()),
        ChangeNotifierProvider(create: (_) => IslandController()),
        ChangeNotifierProvider(create: (_) => JourneysController()),
        ChangeNotifierProvider(create: (_) => GoalsController()),
        ChangeNotifierProvider(create: (_) => JournalController()),
        ChangeNotifierProvider(create: (_) => HabitsController()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNavigator.key,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: screen,
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }
}

Future<void> scrollToEnd(WidgetTester tester, {int drags = 10}) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < drags; i++) {
    await tester.drag(list, const Offset(0, -600), warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}
