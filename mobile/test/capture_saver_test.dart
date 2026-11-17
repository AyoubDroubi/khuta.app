import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/capture/data/rule_parser.dart';
import 'package:khuta/features/capture/state/capture_draft.dart';
import 'package:khuta/features/capture/state/capture_saver.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

import 'support/app_harness.dart';

final _today = DateTime(2026, 11, 16);

class _FailingJournal extends JournalController {
  @override
  Future<JournalEntry> create({
    required String date,
    required JournalEntryKind kind,
    required String text,
    int? minutes,
    List<String> photos = const [],
    String? id,
  }) {
    if (text == 'boom') throw StateError('disk full');
    return super.create(
      date: date,
      kind: kind,
      text: text,
      minutes: minutes,
      photos: photos,
      id: id,
    );
  }
}

// The real controllers add to memory before the write finishes; a write that
// then fails leaves an item in the list that was never saved.
class _GhostTodos extends TodosController {
  @override
  Future<Todo> create({
    required String text,
    String date = '',
    int? minutes,
    TodoPriority priority = TodoPriority.none,
    List<String> photos = const [],
    List<String> tags = const [],
    String project = '',
    List<TodoStep> steps = const [],
    String? id,
  }) async {
    await super.create(text: text, date: date, minutes: minutes, id: id);
    throw StateError('write failed after the item was added');
  }
}

class _GhostJournal extends JournalController {
  @override
  Future<JournalEntry> create({
    required String date,
    required JournalEntryKind kind,
    required String text,
    int? minutes,
    List<String> photos = const [],
    String? id,
  }) async {
    await super.create(date: date, kind: kind, text: text, id: id);
    throw StateError('write failed after the entry was added');
  }
}

// While this save's write is failing, something else in the app adds a to-do.
class _BusyGhostTodos extends TodosController {
  @override
  Future<Todo> create({
    required String text,
    String date = '',
    int? minutes,
    TodoPriority priority = TodoPriority.none,
    List<String> photos = const [],
    List<String> tags = const [],
    String project = '',
    List<TodoStep> steps = const [],
    String? id,
  }) async {
    await super.create(text: text, id: id);
    await super.create(text: 'from the home widget');
    throw StateError('write failed after the item was added');
  }
}

class _SlowTodos extends TodosController {
  final gate = Completer<void>();

  @override
  Future<Todo> create({
    required String text,
    String date = '',
    int? minutes,
    TodoPriority priority = TodoPriority.none,
    List<String> photos = const [],
    List<String> tags = const [],
    String project = '',
    List<TodoStep> steps = const [],
    String? id,
  }) async {
    await gate.future;
    return super.create(text: text, date: date, minutes: minutes, id: id);
  }
}

ProposedItem _task(String title, {DateTime? day, int? minutes}) =>
    ProposedItem(kind: ProposedKind.task, title: title, day: day, minutes: minutes);

ProposedItem _note(String title) =>
    ProposedItem(kind: ProposedKind.note, title: title);

void main() {
  useEmptyStore();

  group('saveProposedItems', () {
    test('a task is stored with its day, time, priority, project and tags',
        () async {
      final todos = TodosController();
      final result = await saveProposedItems(
        [
          ProposedItem(
            kind: ProposedKind.task,
            title: 'اجتماع',
            day: DateTime(2026, 11, 19),
            minutes: 1020,
            priority: TodoPriority.high,
            project: 'p1',
            tags: const ['l1'],
          ),
        ],
        todos: todos,
        journal: JournalController(),
        today: _today,
      );
      expect(result.failed, isEmpty);
      final stored = TodosController().all.single;
      expect(stored.text, 'اجتماع');
      expect(stored.date, '19-11-2026');
      expect(stored.minutes, 1020);
      expect(stored.priority, TodoPriority.high);
      expect(stored.project, 'p1');
      expect(stored.tags, ['l1']);
    });

    test('a task without a day is stored with no date', () async {
      await saveProposedItems(
        [_task('هدية')],
        todos: TodosController(),
        journal: JournalController(),
        today: _today,
      );
      expect(TodosController().all.single.date, '');
    });

    test('a note becomes a new journal moment on today, never replacing one',
        () async {
      final journal = JournalController();
      await saveProposedItems(
        [_note('فكرة أولى')],
        todos: TodosController(),
        journal: journal,
        today: _today,
      );
      await saveProposedItems(
        [_note('فكرة ثانية')],
        todos: TodosController(),
        journal: journal,
        today: _today,
      );
      final entries = JournalController().all;
      expect(entries, hasLength(2));
      expect(entries.every((e) => e.date == '16-11-2026'), isTrue);
      expect(entries.every((e) => e.kind == JournalEntryKind.moment), isTrue);
    });

    test('an item that needs a time stops everything before any write',
        () async {
      final todos = TodosController();
      final journal = JournalController();
      final needs = const ProposedItem(
        kind: ProposedKind.task,
        title: 'اتصل بأمي',
        askedToRemind: true,
      );
      await expectLater(
        saveProposedItems([_task('هدية'), _note('x'), needs],
            todos: todos, journal: journal, today: _today),
        throwsStateError,
      );
      expect(TodosController().all, isEmpty);
      expect(JournalController().all, isEmpty);
    });

    test('a failed to-do write leaves no ghost in memory or in the store',
        () async {
      final todos = _GhostTodos();
      final item = _task('اشتري خبز');
      final result = await saveProposedItems(
        [item],
        todos: todos,
        journal: JournalController(),
        today: _today,
      );
      expect(result.failed, [item]);
      expect(todos.all, isEmpty);
      expect(TodosController().all, isEmpty);
    });

    test('a failed note write leaves no ghost either', () async {
      final journal = _GhostJournal();
      final result = await saveProposedItems(
        [_note('فكرة')],
        todos: TodosController(),
        journal: journal,
        today: _today,
      );
      expect(result.failed, hasLength(1));
      expect(journal.all, isEmpty);
      expect(JournalController().all, isEmpty);
    });

    test('retrying a failed item does not duplicate it', () async {
      final draft = CaptureDraft([_task('اشتري خبز')]);
      final todos = _GhostTodos();
      await draft.save(todos: todos, journal: JournalController(), today: _today);
      expect(draft.rows, hasLength(1));
      final healthy = TodosController();
      await draft.save(todos: healthy, journal: JournalController(), today: _today);
      expect(TodosController().all, hasLength(1));
    });

    test('review 2: rollback removes only the item this save created',
        () async {
      final todos = _BusyGhostTodos();
      final result = await saveProposedItems(
        [_task('اشتري خبز')],
        todos: todos,
        journal: JournalController(),
        today: _today,
      );
      expect(result.failed, hasLength(1));
      expect(todos.all.map((t) => t.text), ['from the home widget']);
    });

    test('a failed write is reported and the others are still saved', () async {
      final journal = _FailingJournal();
      final boom = _note('boom');
      final result = await saveProposedItems(
        [_task('أولى'), boom, _task('ثالثة')],
        todos: TodosController(),
        journal: journal,
        today: _today,
      );
      expect(result.failed, [boom]);
      expect(result.saved, hasLength(2));
      expect(TodosController().all, hasLength(2));
    });
  });

  group('CaptureDraft', () {
    test('saveBlocked follows the checked items that need a time', () {
      final draft = CaptureDraft([
        _task('هدية'),
        const ProposedItem(
          kind: ProposedKind.task,
          title: 'اتصل',
          askedToRemind: true,
        ),
      ]);
      expect(draft.saveBlocked, isTrue);
      draft.setMinutes(1, 600);
      expect(draft.saveBlocked, isFalse);
      draft.setMinutes(1, null);
      expect(draft.saveBlocked, isTrue);
      draft.unmarkRemind(1);
      expect(draft.saveBlocked, isFalse);
      draft.toggle(0);
      draft.toggle(1);
      expect(draft.saveBlocked, isTrue, reason: 'nothing is checked');
    });

    test('an unchecked or removed item is never saved', () async {
      final draft = CaptureDraft([_task('أ'), _task('ب'), _task('ج')]);
      draft.toggle(0);
      draft.remove(2);
      final result = await draft.save(
        todos: TodosController(),
        journal: JournalController(),
        today: _today,
      );
      expect(result!.saved.map((i) => i.title), ['ب']);
      expect(TodosController().all.map((t) => t.text), ['ب']);
      expect(draft.rows.map((r) => r.item.title), ['أ']);
    });

    test('editing a row changes what is saved', () async {
      final draft = CaptureDraft([_task('عنوان')]);
      draft.retitle(0, 'عنوان جديد');
      draft.setDay(0, DateTime(2026, 11, 20));
      draft.setMinutes(0, 540);
      await draft.save(
        todos: TodosController(),
        journal: JournalController(),
        today: _today,
      );
      final t = TodosController().all.single;
      expect(t.text, 'عنوان جديد');
      expect(t.date, '20-11-2026');
      expect(t.minutes, 540);
    });

    test('a blank title blocks saving', () {
      final draft = CaptureDraft([_task('عنوان')]);
      draft.retitle(0, '   ');
      expect(draft.saveBlocked, isTrue);
    });

    test('clearProject removes the project from the row', () {
      final draft = CaptureDraft([
        const ProposedItem(kind: ProposedKind.task, title: 'x', project: 'p1'),
      ]);
      draft.clearProject(0);
      expect(draft.rows.single.item.project, '');
    });

    test('clearPriority resets a row to no priority', () {
      final draft = CaptureDraft([
        const ProposedItem(
          kind: ProposedKind.task,
          title: 'x',
          priority: TodoPriority.high,
        ),
      ]);
      draft.clearPriority(0);
      expect(draft.rows.single.item.priority, TodoPriority.none);
    });

    test('toggleKind turns a note into a task and back, keeping the title',
        () {
      final draft = CaptureDraft([_note('فكرة')]);
      draft.toggleKind(0);
      expect(draft.rows.single.item.kind, ProposedKind.task);
      expect(draft.rows.single.item.title, 'فكرة');
      draft.toggleKind(0);
      expect(draft.rows.single.item.kind, ProposedKind.note);
    });

    test('a note made a task is saved as a to-do', () async {
      final draft = CaptureDraft([_note('فكرة')]);
      draft.toggleKind(0);
      await draft.save(
        todos: TodosController(),
        journal: JournalController(),
        today: _today,
      );
      expect(TodosController().all.single.text, 'فكرة');
      expect(JournalController().all, isEmpty);
    });

    test('review 2: row ids never repeat across drafts', () {
      final a = CaptureDraft([_task('أ'), _task('ب')]);
      final b = CaptureDraft([_task('ج'), _task('د')]);
      expect(
        a.rows.map((r) => r.id).toSet().intersection(b.rows.map((r) => r.id).toSet()),
        isEmpty,
      );
    });

    test('review 2: disposing the draft while it saves does not throw',
        () async {
      final todos = _SlowTodos();
      final draft = CaptureDraft([_task('أ')]);
      final saving = draft.save(
        todos: todos,
        journal: JournalController(),
        today: _today,
      );
      draft.dispose();
      todos.gate.complete();
      expect((await saving)!.saved, hasLength(1));
    });

    test('review 2: a row retitled while saving still leaves the draft',
        () async {
      final todos = _SlowTodos();
      final draft = CaptureDraft([_task('أ'), _task('ب')]);
      draft.toggle(1);
      final saving = draft.save(
        todos: todos,
        journal: JournalController(),
        today: _today,
      );
      draft.retitle(0, 'أ معدّل');
      todos.gate.complete();
      await saving;
      expect(draft.rows.map((r) => r.item.title), ['ب']);
    });

    test('review 2: a picked day and time already past are flagged', () {
      final draft = CaptureDraft(
        [
          const ProposedItem(
            kind: ProposedKind.task,
            title: 'اتصل',
            askedToRemind: true,
          ),
        ],
        now: () => DateTime(2026, 11, 16, 18, 0),
      );
      draft.setDay(0, DateTime(2026, 11, 16));
      draft.setMinutes(0, 540);
      expect(draft.rows.single.item.timePassed, isTrue);
      draft.setDay(0, DateTime(2026, 11, 17));
      expect(draft.rows.single.item.timePassed, isFalse);
    });

    test('review 2: a to-do turned into a note loses its project and labels',
        () {
      final draft = CaptureDraft([
        const ProposedItem(
          kind: ProposedKind.task,
          title: 'x',
          project: 'p1',
          tags: ['l1'],
        ),
      ]);
      draft.toggleKind(0);
      expect(draft.rows.single.item.project, '');
      expect(draft.rows.single.item.tags, isEmpty);
    });

    test('review 2: a long note turned into a to-do is capped', () {
      final draft = CaptureDraft([_note(List.filled(400, 'ا').join())]);
      draft.toggleKind(0);
      expect(draft.rows.single.item.title.length, maxTodoTitle);
    });

    test('review 3: the number of failed rows is kept for the sheet', () async {
      final draft = CaptureDraft([_task('أولى'), _note('boom')]);
      expect(draft.lastFailed, 0);
      await draft.save(
        todos: TodosController(),
        journal: _FailingJournal(),
        today: _today,
      );
      expect(draft.lastFailed, 1);
    });

    test('review 4: a note is never flagged as passed', () {
      final draft = CaptureDraft([_note('فكرة')],
          now: () => DateTime(2026, 11, 16, 18, 0));
      draft.setDay(0, DateTime(2026, 11, 16));
      draft.setMinutes(0, 540);
      expect(draft.rows.single.item.timePassed, isFalse);
    });

    test('review 4: a flagged to-do turned into a note loses the flag', () {
      final draft = CaptureDraft([
        ProposedItem(
          kind: ProposedKind.task,
          title: 'x',
          day: DateTime(2026, 11, 16),
          minutes: 540,
          timePassed: true,
        ),
      ]);
      draft.toggleKind(0);
      expect(draft.rows.single.item.timePassed, isFalse);
    });

    test('removeTag drops one label and keeps the others', () {
      final draft = CaptureDraft([
        const ProposedItem(
          kind: ProposedKind.task,
          title: 'x',
          tags: ['l1', 'l2'],
        ),
      ]);
      draft.removeTag(0, 'l1');
      expect(draft.rows.single.item.tags, ['l2']);
    });

    test('every row keeps its id when an earlier row is removed', () {
      final draft = CaptureDraft([_task('أ'), _task('ب'), _task('ج')]);
      final ids = draft.rows.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(3));
      draft.remove(0);
      expect(draft.rows.map((r) => r.id), [ids[1], ids[2]]);
    });

    test('a double tap saves each item once and the second call is a no-op',
        () async {
      final draft = CaptureDraft([_task('أ'), _task('ب')]);
      final todos = TodosController();
      final journal = JournalController();
      final first = draft.save(todos: todos, journal: journal, today: _today);
      final second = draft.save(todos: todos, journal: journal, today: _today);
      expect(await second, isNull);
      expect((await first)!.saved, hasLength(2));
      expect(TodosController().all, hasLength(2));
      expect(draft.saving, isFalse);
    });

    test('a failed item stays in the draft, the saved ones leave it', () async {
      final draft = CaptureDraft([_task('أولى'), _note('boom')]);
      final result = await draft.save(
        todos: TodosController(),
        journal: _FailingJournal(),
        today: _today,
      );
      expect(result!.failed, hasLength(1));
      expect(draft.rows.map((r) => r.item.title), ['boom']);
      expect(TodosController().all, hasLength(1));
    });
  });
}
