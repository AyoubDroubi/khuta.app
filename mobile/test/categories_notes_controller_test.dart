import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/habits/data/category.dart';
import 'package:khuta/features/habits/data/habit_note.dart';
import 'package:khuta/features/habits/state/categories_controller.dart';
import 'package:khuta/features/habits/state/notes_controller.dart';

import 'support/app_harness.dart';

// categories and notes keep their order and queries,
// and store every change.
void main() {
  useEmptyStore();

  group('categories', () {
    test('create appends after the highest order and is stored', () async {
      final c = CategoriesController();
      final a = await c.create(name: 'Faith', color: const Color(0xFF94492F), icon: 'star');
      final b = await c.create(name: 'Study', color: const Color(0xFF0A84FF), icon: 'book');
      expect(b.order, greaterThan(a.order));
      final again = CategoriesController();
      expect(again.categories.map((x) => x.name), containsAllInOrder(['Faith', 'Study']));
      expect(again.byName('Faith')!.id, a.id);
      expect(again.byName('Nope'), isNull);
    });

    test('update changes one category; an unknown id is ignored', () async {
      final c = CategoriesController();
      final a = await c.create(name: 'Faith', color: const Color(0xFF94492F), icon: 'star');
      await c.update(a.copyWith(name: 'Prayer'));
      expect(CategoriesController().byName('Prayer'), isNotNull);
      expect(CategoriesController().byName('Faith'), isNull);
      final before = c.categories.length;
      await c.update(Category(id: 'ghost', name: 'Ghost', color: Colors.red, icon: 'star'));
      expect(c.categories.length, before);
      expect(c.byName('Ghost'), isNull);
    });

    test('remove deletes it from the store', () async {
      final c = CategoriesController();
      final a = await c.create(name: 'Faith', color: const Color(0xFF94492F), icon: 'star');
      await c.remove(a.id);
      expect(c.byName('Faith'), isNull);
      expect(CategoriesController().byName('Faith'), isNull);
    });

    test('reorder renumbers and persists the new order', () async {
      final c = CategoriesController();
      final a = await c.create(name: 'A', color: Colors.red, icon: 'star');
      final b = await c.create(name: 'B', color: Colors.green, icon: 'star');
      final d = await c.create(name: 'D', color: Colors.blue, icon: 'star');
      await c.reorder([d, a, b]);
      final names = CategoriesController().categories.map((x) => x.name).toList();
      expect(names, ['D', 'A', 'B']);
      expect(CategoriesController().categories.map((x) => x.order), [0, 1, 2]);
    });

    test('with an empty store, reload seeds the six default categories once', () async {
      final c = CategoriesController();
      c.reload();
      // Seeding runs in the background; wait for its six writes.
      for (var i = 0; i < 100 && c.categories.length < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(c.categories.map((x) => x.name).toSet(), CategoriesController.seededNames);
      expect(CategoriesController().categories.length, 6);
      c.reload(); // the store now has categories: nothing more is added
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.categories.length, 6);
    });
  });

  group('notes', () {
    Future<HabitNote> add(NotesController c, String habit, String day, NoteType type,
            {String text = 'x', int? minutes, List<String> photos = const []}) =>
        c.create(habitId: habit, dayKey: day, type: type, text: text, minutes: minutes, photos: photos);

    test('create trims the text and stores the note', () async {
      final c = NotesController();
      final n = await add(c, 'h', '08-11-2026', NoteType.note, text: '  hello  ');
      expect(n.text, 'hello');
      expect(NotesController().all.single.id, n.id);
    });

    test('forDay is sorted by time with untimed notes last', () async {
      final c = NotesController();
      await add(c, 'h', '08-11-2026', NoteType.note, text: 'late', minutes: 600);
      await add(c, 'h', '08-11-2026', NoteType.note, text: 'none');
      await add(c, 'h', '08-11-2026', NoteType.planned, text: 'early', minutes: 60);
      await add(c, 'h', '09-11-2026', NoteType.note, text: 'other day');
      await add(c, 'z', '08-11-2026', NoteType.note, text: 'other habit');
      expect(c.forDay('h', '08-11-2026').map((n) => n.text), ['early', 'late', 'none']);
      expect(c.countFor('h', '08-11-2026'), 3);
      expect(c.typesFor('h', '08-11-2026'), {NoteType.note, NoteType.planned});
      expect(c.hasAny('h'), isTrue);
      expect(c.hasAny('nobody'), isFalse);
    });

    test('byDate lists the newest day first, optionally for one habit', () async {
      final c = NotesController();
      await add(c, 'h', '07-11-2026', NoteType.note, text: 'old');
      await add(c, 'h', '09-11-2026', NoteType.note, text: 'new');
      await add(c, 'z', '08-11-2026', NoteType.note, text: 'mid');
      expect(c.byDate().map((n) => n.text), ['new', 'mid', 'old']);
      expect(c.byDate(habitId: 'h').map((n) => n.text), ['new', 'old']);
    });

    test('photo helpers count photos and list the newest note first', () async {
      final c = NotesController();
      await add(c, 'h', '07-11-2026', NoteType.note, text: 'one', photos: ['a.jpg']);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await add(c, 'h', '08-11-2026', NoteType.note, text: 'two', photos: ['b.jpg', 'c.jpg']);
      await add(c, 'h', '08-11-2026', NoteType.note, text: 'none');
      expect(c.photoCount('h'), 3);
      expect(c.photoNotes('h').map((n) => n.text), ['two', 'one']);
    });

    test('update replaces a note; an unknown id is ignored', () async {
      final c = NotesController();
      final n = await add(c, 'h', '08-11-2026', NoteType.note, text: 'before');
      await c.update(n.copyWith(text: 'after'));
      expect(NotesController().all.single.text, 'after');
      await c.update(HabitNote(
        id: 'ghost',
        habitId: 'h',
        date: '08-11-2026',
        type: NoteType.note,
        text: 'ghost',
        createdAt: DateTime.now(),
      ));
      expect(c.all, hasLength(1));
      expect(NotesController().all.single.text, 'after');
    });

    test('remove and removeForHabit delete from the store', () async {
      final c = NotesController();
      final a = await add(c, 'h', '08-11-2026', NoteType.note, text: 'a');
      await add(c, 'h', '09-11-2026', NoteType.note, text: 'b');
      await add(c, 'z', '08-11-2026', NoteType.note, text: 'c');
      await c.remove(a.id);
      expect(NotesController().all.map((n) => n.text).toSet(), {'b', 'c'});
      await c.removeForHabit('h');
      expect(NotesController().all.map((n) => n.text), ['c']);
    });

    test('reload picks up notes written elsewhere', () async {
      final a = NotesController();
      final b = NotesController();
      await add(a, 'h', '08-11-2026', NoteType.note);
      expect(b.all, isEmpty);
      b.reload();
      expect(b.all, hasLength(1));
    });
  });
}
