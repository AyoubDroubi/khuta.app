import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/capture/data/capture_normalize.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/capture/data/rule_parser.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';

// Reference time for every expectation: Monday 2026-11-16, 09:00.
final _today = DateTime(2026, 11, 16);
final _now = DateTime(2026, 11, 16, 9, 0);

Future<List<ProposedItem>> _parse(
  String text, {
  List<TodoTag> projects = const [],
  List<TodoTag> labels = const [],
}) =>
    const RuleParser().parse(
      text,
      now: _now,
      today: _today,
      projects: projects,
      labels: labels,
    );

// What a gold day token means at the reference time. Weekdays are the next
// occurrence; Monday (today's weekday) means next Monday.
final _days = <String, DateTime?>{
  '': null,
  'today': DateTime(2026, 11, 16),
  'tomorrow': DateTime(2026, 11, 17),
  'day_after_tomorrow': DateTime(2026, 11, 18),
  'mon': DateTime(2026, 11, 23),
  'tue': DateTime(2026, 11, 17),
  'wed': DateTime(2026, 11, 18),
  'thu': DateTime(2026, 11, 19),
  'fri': DateTime(2026, 11, 20),
  'sat': DateTime(2026, 11, 21),
  'sun': DateTime(2026, 11, 22),
};

int? _minutes(String hhmm) => hhmm.isEmpty
    ? null
    : int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3));

TodoPriority _priority(String p) => switch (p) {
      'high' => TodoPriority.high,
      'low' => TodoPriority.low,
      'medium' => TodoPriority.medium,
      _ => TodoPriority.none,
    };

List<Map<String, dynamic>> _corpus(String name) =>
    (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

/// Why [items] do not match [gold], or null when they do.
String? _mismatch(List<ProposedItem> items, List gold) {
  if (items.length != gold.length) {
    return 'expected ${gold.length} items, got ${items.length}';
  }
  for (var i = 0; i < gold.length; i++) {
    final g = gold[i] as Map<String, dynamic>;
    final it = items[i];
    final kind = g['type'] == 'note' ? ProposedKind.note : ProposedKind.task;
    if (it.kind != kind) return 'item $i kind ${it.kind}';
    if (it.askedToRemind != g['remind']) return 'item $i remind';
    if (it.day != _days[g['day']]) return 'item $i day ${it.day}';
    if (it.minutes != _minutes(g['time'] as String)) {
      return 'item $i minutes ${it.minutes}';
    }
    if (it.priority != _priority(g['prio'] as String)) {
      return 'item $i priority ${it.priority}';
    }
    if (!foldLetters(it.title).contains(foldLetters(g['kw'] as String))) {
      return 'item $i title "${it.title}" lacks "${g['kw']}"';
    }
  }
  return null;
}

// Sentences the rules are known not to get right yet, each with why. None of
// them is the headline sentence or a single-item sentence.
const _knownMisses = <String, String>{
  // A lone "و" between verbs is deliberately not a split point (a wrong split
  // is worse than one editable item); the model parser is for these.
  'بدي أشتري هدية وأحجز عند الدكتور يوم الخميس': 'lone و not split',
  'بدي أدفع القسط وأجدد الإقامة وأشتري خبز': 'lone و not split',
  // A day or time said once for several items is not shared across clauses
  // (design: left for later, the model parser's job).
  'بكرة الصبح رياضة وبعدين أراجع الدرس': 'day not shared across clauses',
  'الثلاثاء الساعة 10 الصبح مقابلة عمل ضروري وبعدين الساعة 2 العصر غداء مع ماما':
      'day not shared across clauses',
  'الجمعة الصبح صلاة الجمعة ثم زيارة الأهل': 'day not shared across clauses',
};

void main() {
  test('the headline sentence gives three items', () async {
    final items = await _parse(
      'الخميس عندي اجتماع الساعة 5 العصر، وبدي أشتري هدية، وذكرني أتصل بأمي',
    );
    expect(items, hasLength(3));
    expect(items[0].title, contains('اجتماع'));
    expect(items[0].day, DateTime(2026, 11, 19));
    expect(items[0].minutes, 1020);
    expect(items[1].title, contains('هدية'));
    expect(items[1].day, isNull);
    expect(items[1].minutes, isNull);
    expect(items[2].title, contains('أتصل'));
    expect(items[2].askedToRemind, isTrue);
    expect(items[2].minutes, isNull);
    expect(items[2].needsTime, isTrue);
    expect(items[2].day, isNull);
  });

  for (final file in ['capture_spike_cases.json', 'capture_heldout.json']) {
    group('corpus $file', () {
      for (final c in _corpus(file)) {
        final text = c['t'] as String;
        test(text, () async {
          final problem = _mismatch(await _parse(text), c['g'] as List);
          if (_knownMisses.containsKey(text)) {
            expect(problem, isNotNull,
                reason: 'listed as a known miss but now passes: remove it');
          } else {
            expect(problem, isNull);
          }
        });
      }
    });
  }

  test('known misses are never single-item sentences or the headline', () {
    final all = [..._corpus('capture_spike_cases.json'), ..._corpus('capture_heldout.json')];
    for (final text in _knownMisses.keys) {
      final c = all.firstWhere((c) => c['t'] == text);
      expect((c['g'] as List).length, greaterThan(1), reason: text);
    }
  });

  group('review: a day or time said in another clause', () {
    test('a day in the next clause reaches the item with a bare time', () async {
      final items = await _parse('اجتماع الساعة 5 العصر، يوم الخميس');
      expect(items, hasLength(1));
      expect(items.single.day, DateTime(2026, 11, 19));
      expect(items.single.minutes, 1020);
    });

    test('a time in the next clause is resolved against the first day', () async {
      final items = await _parse('اجتماع بكرة، الساعة 12 بالليل');
      expect(items, hasLength(1));
      expect(items.single.day, DateTime(2026, 11, 18));
      expect(items.single.minutes, 0);
    });

    test('a leading clause with only a day and time goes to the next item',
        () async {
      final items = await _parse('بكرة الساعة 5 العصر، اجتماع مع أحمد');
      expect(items, hasLength(1));
      expect(items.single.title, contains('اجتماع'));
      expect(items.single.day, DateTime(2026, 11, 17));
      expect(items.single.minutes, 1020);
    });

    test('a leading day-only clause too', () async {
      final items = await _parse('بكرة الصبح، اشتري خبز');
      expect(items.single.day, DateTime(2026, 11, 17));
    });

    test('a leading importance-only clause too', () async {
      final items = await _parse('ضروري جدا، اشتري خبز');
      expect(items.single.priority, TodoPriority.high);
    });
  });

  test('review 2: a to-do title is capped at the composer limit', () async {
    final long = List.filled(120, 'كلمة').join(' ');
    final items = await _parse(long);
    expect(items.single.title.length, lessThanOrEqualTo(maxTodoTitle));
  });

  test('review 2: a long note keeps its full text', () async {
    final long = 'ملاحظة: ${List.filled(120, 'كلمة').join(' ')}';
    final items = await _parse(long);
    expect(items.single.title.length, greaterThan(maxTodoTitle));
  });

  test('a note is a note, with no priority', () async {
    final items = await _parse('سجل ملاحظة: فكرة تطبيق للتوصيل للقرى');
    expect(items, hasLength(1));
    expect(items.single.kind, ProposedKind.note);
    expect(items.single.priority, TodoPriority.none);
    expect(items.single.title, 'فكرة تطبيق للتوصيل للقرى');
  });

  test('known project and label names give their ids', () async {
    const home = TodoTag(
      id: 'p1',
      name: 'البيت',
      color: Colors.red,
      kind: TodoTagKind.project,
    );
    final items = await _parse('بكرة أنظف البيت', projects: [home]);
    expect(items.single.project, 'p1');
  });

  test('a project that does not exist never appears', () async {
    final items = await _parse('بكرة أنظف البيت');
    expect(items.single.project, '');
    expect(items.single.tags, isEmpty);
  });

  test('empty, blank, punctuation-only and emoji-only input give nothing',
      () async {
    for (final s in ['', '   ', '،،،', '!!!', '😀😀', '\n\n']) {
      expect(await _parse(s), isEmpty, reason: '"$s"');
    }
  });

  test('a 10,000-character input is bounded', () async {
    final sw = Stopwatch()..start();
    final items = await _parse('اشتري خبز، ' * 1000);
    expect(items.length, lessThanOrEqualTo(20));
    expect(sw.elapsed.inSeconds, lessThan(2));
  });

  test('diacritics, Arabic-Indic digits and spelling variants parse alike',
      () async {
    final plain = await _parse('ذكرني بكره الساعه 5 العصر ادفع الايجار ضروري');
    final dressed = await _parse('ذكِّرني بكرة الساعة ٥ العصر أدفع الإيجار ضروري');
    expect(plain, hasLength(1));
    expect(dressed, hasLength(1));
    expect(dressed.single.day, plain.single.day);
    expect(dressed.single.minutes, plain.single.minutes);
    expect(dressed.single.priority, plain.single.priority);
    expect(dressed.single.askedToRemind, plain.single.askedToRemind);
  });
}
