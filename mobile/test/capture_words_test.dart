import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/capture/data/capture_normalize.dart';
import 'package:khuta/features/capture/data/capture_when.dart';
import 'package:khuta/features/capture/data/capture_words.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';

String _title(String clause) {
  final m = findWhen(foldLetters(clause));
  return buildTitle(clause, m.spans);
}

TodoPriority _prio(String s) => findPriority(foldLetters(s));

void main() {
  group('findPriority', () {
    test('importance words mean high', () {
      expect(_prio('اجتماع مهم'), TodoPriority.high);
      expect(_prio('ضروري جدا'), TodoPriority.high);
      expect(_prio('عاجل'), TodoPriority.high);
      expect(_prio('this is urgent'), TodoPriority.high);
    });

    test('"not important" and "if I have time" mean low', () {
      expect(_prio('مش مهم'), TodoPriority.low);
      expect(_prio('لو فضيت بدي أرتب'), TodoPriority.low);
    });

    test('low wins over high, and no word means none', () {
      expect(_prio('مش مهم بس ضروري'), TodoPriority.low);
      expect(_prio('اجتماع'), TodoPriority.none);
    });

    test('a word that only contains the importance word is not one', () {
      expect(_prio('مهمة جديدة'), TodoPriority.none);
    });
  });

  group('type words', () {
    test('asksToRemind', () {
      expect(asksToRemind(foldLetters('ذكرني أتصل')), isTrue);
      expect(asksToRemind(foldLetters('نبهني بعد ساعة')), isTrue);
      expect(asksToRemind(foldLetters('remind me to call')), isTrue);
      expect(asksToRemind(foldLetters('اتصل بأمي')), isFalse);
    });

    test('isNote', () {
      expect(isNote(foldLetters('ملاحظة: فكرة')), isTrue);
      expect(isNote(foldLetters('سجل ملاحظة كذا')), isTrue);
      expect(isNote(foldLetters('note: milk')), isTrue);
      expect(isNote(foldLetters('كل ما أتذكر: أسأل خالد')), isTrue);
      expect(isNote(foldLetters('سجل المصاريف')), isFalse);
      expect(isNote(foldLetters('اشتري ملح')), isFalse);
    });
  });

  group('matchKnown', () {
    const home = TodoTag(
      id: 'p1',
      name: 'مشروع البيت',
      color: Colors.red,
      kind: TodoTagKind.project,
    );
    const urgent = TodoTag(id: 'l1', name: 'عاجل', color: Colors.blue);

    test('returns the ids of the names that occur', () {
      final r = matchKnown(
        foldLetters('شغل مشروع البيت عاجل'),
        projects: [home],
        labels: [urgent],
      );
      expect(r.project, 'p1');
      expect(r.tags, ['l1']);
    });

    test('text naming neither returns nothing', () {
      final r = matchKnown(
        foldLetters('اشتري خبز'),
        projects: [home],
        labels: [urgent],
      );
      expect(r.project, '');
      expect(r.tags, isEmpty);
    });

    test('an unknown name never produces an id', () {
      final r = matchKnown(
        foldLetters('مشروع السيارة'),
        projects: [home],
        labels: const [],
      );
      expect(r.project, '');
    });
  });

  group('review: negated importance', () {
    test('"not" plus any importance word is low, never high', () {
      for (final s in [
        'مش ضروري اروح عالبنك',
        'مش عاجل',
        'مو ضروري',
        'غير ضروري',
        'ليس مهم',
        'not urgent: clean the garage',
        'not important',
      ]) {
        expect(_prio(s), TodoPriority.low, reason: s);
      }
    });

    test('the negated word does not leave its "not" behind in the title', () {
      expect(_title('مش ضروري اروح عالبنك'), 'اروح عالبنك');
    });
  });

  group('review: a note marker only counts at the start of the clause', () {
    test('notes mentioned inside a sentence are tasks', () {
      for (final s in [
        'send a thank-you note to sara',
        'اكتب ملاحظة للمدير عن التأخير',
        'رد على ملاحظة أحمد',
      ]) {
        expect(isNote(foldLetters(s)), isFalse, reason: s);
      }
    });

    test('and the title keeps the word', () {
      expect(_title('send a thank-you note to Sara'),
          'send a thank-you note to Sara');
      expect(_title('رد على ملاحظة أحمد'), 'رد على ملاحظة أحمد');
    });

    test('a leading marker still makes a note', () {
      for (final s in [
        'ملاحظة: كذا',
        'سجل ملاحظة كذا',
        'note: milk',
        'كل ما أتذكر: أسأل خالد',
      ]) {
        expect(isNote(foldLetters(s)), isTrue, reason: s);
      }
    });
  });

  group('buildTitle', () {
    test('drops "remind me"', () {
      expect(_title('ذكرني أتصل بأمي'), 'أتصل بأمي');
      expect(_title('remind me to water the plants'), 'water the plants');
    });

    test('drops the day, the time and a leading filler', () {
      final t = _title('بكرة عندي اجتماع الساعة 10 الصبح');
      expect(t, contains('اجتماع'));
      expect(t, isNot(contains('بكرة')));
      expect(t, isNot(contains('الساعة')));
      expect(t, isNot(contains('عندي')));
    });

    test('drops importance words but keeps words that contain them', () {
      final t = _title('ضروري جدا أخلص تقرير المشروع اليوم');
      expect(t, contains('تقرير'));
      expect(t, isNot(contains('ضروري')));
      expect(t, isNot(contains('جدا')));
      expect(_title('مهمة جديدة للبيت'), contains('مهمة'));
    });

    test('drops a dangling connective at the end', () {
      final t = _title('لازم أراجع العقد وهاد عاجل');
      expect(t, contains('العقد'));
      expect(t, isNot(endsWith('وهاد')));
    });

    test('drops the note marker and its colon', () {
      expect(_title('ملاحظة: فكرة تطبيق للتوصيل'), 'فكرة تطبيق للتوصيل');
    });

    test('keeps the typed spelling, not the folded one', () {
      expect(_title('اشتري هدية لأمي'), 'اشتري هدية لأمي');
    });

    test('a clause that is only a day word has no title', () {
      expect(_title('بكرة'), '');
    });
  });
}
