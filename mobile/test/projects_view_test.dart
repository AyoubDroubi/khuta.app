import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';
import 'package:khuta/features/todos/data/projects_view.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';
import 'package:khuta/features/todos/pages/todos_page.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:khuta/features/todos/widgets/project_tile.dart';
import 'package:khuta/features/todos/widgets/todo_tag_sheet.dart';
import 'package:khuta/features/todos/widgets/todo_tile.dart';

import 'support/app_harness.dart';

// The Tasks tab can show projects as folders, a list, cards or chips
// (Settings → Preferences → Projects view).
void tw(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });

void main() {
  useEmptyStore();

  Future<void> seed(WidgetTester tester, {bool ar = false}) =>
      tester.runAsync(() async {
        const colors = [Color(0xFF94492F), Color(0xFF0A84FF), Color(0xFFBF5AF2)];
        final names = ar
            ? ['العمل', 'شخصي', 'دراسة']
            : ['Work', 'Personal', 'Study'];
        for (var i = 0; i < 3; i++) {
          await LocalStore.writeTodoTag(TodoTag(
            id: 'p$i',
            name: names[i],
            color: colors[i],
            order: i,
            kind: TodoTagKind.project,
          ));
        }
        final todos = [
          for (var i = 0; i < 3; i++)
            Todo(id: 'w$i', text: 'Work task $i', project: 'p0', done: i == 0, createdAt: AppClock.now()),
          Todo(id: 'x0', text: 'Buy a gift', project: 'p1', createdAt: AppClock.now()),
          Todo(id: 'x1', text: 'Study chapter', project: 'p2', done: true, createdAt: AppClock.now()),
          Todo(id: 'x2', text: 'Loose task', createdAt: AppClock.now()),
        ];
        for (final todo in todos) {
          await LocalStore.writeTodo(todo);
        }
      });

  Map<String, Object> view(ProjectsView v, {int style = 0}) =>
      {'todoProjectsView': v.index, 'appStyle': style};

  test('the default view is the list and the setting survives a restart', () async {
    expect(SettingsController().projectsView, ProjectsView.list);
    await SettingsController().setProjectsView(ProjectsView.chips);
    expect(SettingsController().projectsView, ProjectsView.chips);
    final saved = LocalStore.backupSettings();
    expect(saved['todoProjectsView'], ProjectsView.chips.index);
    await SettingsController().setProjectsView(ProjectsView.cards);
    await LocalStore.restoreSettings(saved);
    expect(SettingsController().projectsView, ProjectsView.chips);
    expect(ProjectsView.of(99), ProjectsView.list);
    expect(ProjectsView.of('x'), ProjectsView.list);
  });

  test('progress counts done and total per project, "" for loose to-dos', () async {
    final controller = TodosController();
    final a = await controller.create(text: 'a', project: 'p');
    await controller.create(text: 'b', project: 'p');
    await controller.create(text: 'c');
    await controller.toggle(a.id);
    expect(controller.projectProgress('p'), (done: 1, total: 2));
    expect(controller.projectProgress(''), (done: 0, total: 1));
    expect(controller.projectProgress('none'), (done: 0, total: 0));
  });

  for (final style in {0: 'classic', 1: 'minimal', 2: 'express'}.entries) {
    for (final v in [ProjectsView.list, ProjectsView.cards]) {
      tw('${v.name} ${style.value}: name, open count and progress, tap opens', (tester) async {
        await seed(tester);
        await pumpScreen(tester, const TodosPage(),
            settings: view(v, style: style.key), settle: false);
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(ProjectTile), findsNWidgets(4)); // 3 projects + unfiled
        expect(find.text('Work'), findsOneWidget);
        expect(find.textContaining('2 open'), findsOneWidget);
        expect(find.textContaining('1 of 3 done'), findsOneWidget);
        expect(find.text('Personal'), findsOneWidget);

        await tester.tap(find.text('Personal'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ProjectTile), findsNothing);
        expect(find.text('Buy a gift'), findsOneWidget);
        expect(find.text('Work task 1'), findsNothing);
      });
    }

    tw('chips ${style.value}: chips filter the list, no projects screen', (tester) async {
      await seed(tester);
      await pumpScreen(tester, const TodosPage(),
          settings: view(ProjectsView.chips, style: style.key), settle: false);
      await tester.pump(const Duration(seconds: 1));

      expect(find.widgetWithIcon(IconButton, LucideIcons.folder), findsNothing);
      expect(find.widgetWithIcon(IconButton, LucideIcons.list), findsNothing);
      expect(find.widgetWithText(TodoTagChip, 'Work'), findsOneWidget);
      expect(find.text('Work task 1'), findsOneWidget);
      expect(find.text('Buy a gift'), findsOneWidget);

      await tester.tap(find.widgetWithText(TodoTagChip, 'Personal'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Buy a gift'), findsOneWidget);
      expect(find.text('Work task 1'), findsNothing);
      expect(find.byType(TodoTile), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Work task 1'), findsOneWidget);
    });
  }

  tw('folders: the original view still shows the folders grid', (tester) async {
    await seed(tester);
    await pumpScreen(tester, const TodosPage(),
        settings: view(ProjectsView.folders), settle: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProjectTile), findsNothing);
    expect(find.text('Work'), findsOneWidget);
  });

  tw('list: arranging works and the drag sticks', (tester) async {
    await seed(tester);
    await pumpScreen(tester, const TodosPage(), settings: view(ProjectsView.list));

    List<String> order() {
      final found = [
        for (final n in const ['Work', 'Personal', 'Study'])
          (tester.getCenter(find.text(n)).dy, n),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final f in found) f.$2];
    }

    expect(order(), ['Work', 'Personal', 'Study']);
    await tester.tap(find.byIcon(LucideIcons.ellipsis).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rearrange'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final gesture = await tester.startGesture(tester.getCenter(find.text('Work')));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(tester.getCenter(find.text('Study')));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(order(), ['Personal', 'Study', 'Work']);
  });

  for (final v in ProjectsView.values) {
    for (final lang in ['en', 'ar']) {
      for (final style in {0: 'classic', 1: 'minimal', 2: 'express'}.entries) {
        tw('${v.name} ${style.value} $lang at 2x text has no overflow', (tester) async {
          await seed(tester, ar: lang == 'ar');
          await pumpScreen(tester, const TodosPage(),
              settings: view(v, style: style.key),
              locale: Locale(lang),
              textScale: 2,
              settle: false);
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final style in {0: 'classic', 1: 'minimal', 2: 'express'}.entries) {
    tw('${style.value}: Preferences offers the projects view and remembers it', (tester) async {
      await pumpScreen(tester, const SettingsPage(),
          settings: {'appStyle': style.key}, settle: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Preferences'));
      await tester.pump(const Duration(seconds: 1));
      tester.view.physicalSize = const Size(1080, 9000);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Projects view'), findsOneWidget);
      expect(find.text('List'), findsOneWidget); // the default

      await tester.tap(find.text('Projects view'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Chips'));
      await tester.pump(const Duration(seconds: 1));

      expect(LocalStore.setting('todoProjectsView', -1), ProjectsView.chips.index);
    });
  }
}
