import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
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
  }) {
    if (text == 'boom') throw StateError('disk full');
    return super.create(
      date: date,
      kind: kind,
      text: text,
      minutes: minutes,
      photos: photos,
    );
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
