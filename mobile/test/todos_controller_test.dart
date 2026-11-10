import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

import 'support/app_harness.dart';

// to-do state changes are stored and counted right.
void main() {
  useEmptyStore();

  final today = AppClock.today();

  TodosController reloaded() => TodosController();

  group('create / update / toggle / remove', () {
    test('create trims the text, applies defaults and stores the to-do', () async {
      final c = TodosController();
      final t = await c.create(text: '  Pay rent  ');
      expect(t.text, 'Pay rent');
      expect(t.done, isFalse);
      expect(t.priority, TodoPriority.none);
      expect(reloaded().all.single.id, t.id);
    });

    test('update replaces a to-do; an unknown id is ignored', () async {
      final c = TodosController();
      final t = await c.create(text: 'Old');
      await c.update(t.copyWith(text: 'New', priority: TodoPriority.high));
      expect(reloaded().all.single.text, 'New');
      expect(reloaded().all.single.priority, TodoPriority.high);
      await c.update(Todo(id: 'ghost', text: 'Ghost', createdAt: DateTime.now()));
      expect(c.all, hasLength(1));
    });

    test('toggle marks done with a finish time, and toggling again clears it', () async {
      final c = TodosController();
      final t = await c.create(text: 'A');
      await c.toggle(t.id);
      expect(c.all.single.done, isTrue);
      expect(c.all.single.doneAt, isNotNull);
      expect(reloaded().all.single.done, isTrue);
      await c.toggle(t.id);
      expect(c.all.single.done, isFalse);
      expect(c.all.single.doneAt, isNull);
      expect(reloaded().all.single.doneAt, isNull);
      await c.toggle('ghost'); // no effect, no error
    });

    test('steps toggle one at a time', () async {
      final c = TodosController();
      final t = await c.create(
        text: 'Trip',
        steps: const [TodoStep(id: 's1', text: 'Pack'), TodoStep(id: 's2', text: 'Book')],
      );
      await c.toggleStep(t.id, 's2');
      expect(reloaded().all.single.steps.map((s) => s.done), [false, true]);
      await c.toggleStep(t.id, 's2');
      expect(c.all.single.steps.map((s) => s.done), [false, false]);
      await c.toggleStep('ghost', 's1');
    });

    test('remove deletes from the store', () async {
      final c = TodosController();
      final a = await c.create(text: 'A');
      await c.create(text: 'B');
      await c.remove(a.id);
      expect(reloaded().all.map((t) => t.text), ['B']);
    });

    test('clearCompleted removes done to-dos only', () async {
      final c = TodosController();
      final a = await c.create(text: 'A');
      await c.create(text: 'B');
      await c.toggle(a.id);
      await c.clearCompleted();
      expect(c.all.map((t) => t.text), ['B']);
      expect(reloaded().all.map((t) => t.text), ['B']);
      await c.clearCompleted(); // nothing left to clear
      expect(c.all, hasLength(1));
    });
  });

  group('tags and projects', () {
    test('forgetTag removes the tag from every to-do that has it', () async {
      final c = TodosController();
      await c.create(text: 'A', tags: ['t1', 't2']);
      await c.create(text: 'B', tags: ['t2']);
      await c.create(text: 'C');
      await c.forgetTag('t2');
      final tags = {for (final t in reloaded().all) t.text: t.tags};
      expect(tags, {'A': ['t1'], 'B': <String>[], 'C': <String>[]});
      await c.forgetTag('unused'); // nothing touched
    });

    test('forgetProject moves its to-dos out of the project', () async {
      final c = TodosController();
      await c.create(text: 'A', project: 'p1');
      await c.create(text: 'B', project: 'p2');
      await c.forgetProject('p1');
      expect({for (final t in reloaded().all) t.text: t.project}, {'A': '', 'B': 'p2'});
    });

    test('counts only look at unfinished to-dos and respect the project filter', () async {
      final c = TodosController();
      final done = await c.create(text: 'done', tags: ['t1'], project: 'p1');
      await c.create(text: 'a', tags: ['t1'], project: 'p1');
      await c.create(text: 'b', tags: ['t1']);
      await c.create(text: 'c', project: 'p1');
      await c.create(text: 'd');
      await c.toggle(done.id);
      expect(c.countFor('t1'), 2);
      expect(c.countFor('t1', project: 'p1'), 1);
      expect(c.countFor('t1', project: ''), 1, reason: 'no project');
      expect(c.untaggedCount(), 2);
      expect(c.untaggedCount(project: 'p1'), 1);
      expect(c.projectCount('p1'), 2);
      expect(c.looseCount, 2);
      expect(c.pendingCount, 4);
    });
  });

  group('due dates', () {
    test('dueTodayCount counts unfinished to-dos due today or earlier', () async {
      final c = TodosController();
      await c.create(text: 'late', date: today.addDays(-3).dayKey);
      await c.create(text: 'today', date: today.dayKey);
      await c.create(text: 'tomorrow', date: today.addDays(1).dayKey);
      await c.create(text: 'someday');
      final doneLate = await c.create(text: 'doneLate', date: today.addDays(-1).dayKey);
      await c.toggle(doneLate.id);
      expect(c.dueTodayCount, 2);
    });

    test('sections group the pending to-dos and completed lists the finished ones', () async {
      final c = TodosController();
      await c.create(text: 'late', date: today.addDays(-2).dayKey);
      await c.create(text: 'now', date: today.dayKey);
      final finished = await c.create(text: 'finished');
      await c.toggle(finished.id);
      expect(c.sections, isNotEmpty);
      expect(c.sections.expand((s) => s.todos).map((t) => t.text).toSet(), {'late', 'now'});
      expect(c.completed.map((t) => t.text), ['finished']);
    });
  });

  test('reload picks up what another controller stored', () async {
    final a = TodosController();
    final b = TodosController();
    await a.create(text: 'X');
    expect(b.all, isEmpty);
    b.reload();
    expect(b.all, hasLength(1));
  });
}
