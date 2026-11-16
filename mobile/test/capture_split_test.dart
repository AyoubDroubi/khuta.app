import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/capture/data/capture_split.dart';

int _words(String s) => s.trim().split(RegExp(r'\s+')).length;

void main() {
  test('splits on commas and other separators', () {
    expect(splitClauses('اشتري خبز، اتصل بأمي'), ['اشتري خبز', 'اتصل بأمي']);
    expect(splitClauses('buy bread, call mom'), ['buy bread', 'call mom']);
    expect(splitClauses('اشتري خبز؛ اتصل بأمي'), ['اشتري خبز', 'اتصل بأمي']);
    expect(splitClauses('اشتري خبز\nاتصل بأمي'), ['اشتري خبز', 'اتصل بأمي']);
  });

  test('does not split a number with a comma in it', () {
    expect(splitClauses('ادفع 1,234 دينار للبنك'), ['ادفع 1,234 دينار للبنك']);
  });

  test('the headline sentence gives three clauses without the connectives', () {
    expect(
      splitClauses(
        'الخميس عندي اجتماع الساعة 5 العصر، وبدي أشتري هدية، وذكرني أتصل بأمي',
      ),
      ['الخميس عندي اجتماع الساعة 5 العصر', 'بدي أشتري هدية', 'ذكرني أتصل بأمي'],
    );
  });

  test('splits before a conjunction plus a marker, with no comma', () {
    expect(
      splitClauses('الخميس اجتماع مهم وبدي أشتري هدية'),
      ['الخميس اجتماع مهم', 'بدي أشتري هدية'],
    );
    expect(
      splitClauses('عندي امتحان السبت ولازم أذاكر الليلة'),
      ['عندي امتحان السبت', 'لازم أذاكر الليلة'],
    );
    expect(
      splitClauses('اتصل بالبنك ونبهني أدفع الفاتورة'),
      ['اتصل بالبنك', 'نبهني أدفع الفاتورة'],
    );
  });

  test('"and then" words are dropped, not kept in a clause', () {
    expect(
      splitClauses(
        'الثلاثاء الساعة 10 الصبح مقابلة عمل ضروري وبعدين الساعة 2 العصر غداء مع ماما',
      ),
      ['الثلاثاء الساعة 10 الصبح مقابلة عمل ضروري', 'الساعة 2 العصر غداء مع ماما'],
    );
    expect(
      splitClauses('الجمعة الصبح صلاة الجمعة ثم زيارة الأهل'),
      ['الجمعة الصبح صلاة الجمعة', 'زيارة الأهل'],
    );
    expect(
      splitClauses('مراجعة الدرس وبعدها تمرين الجري'),
      ['مراجعة الدرس', 'تمرين الجري'],
    );
  });

  test('a conjunction after a comma is dropped from the next clause', () {
    expect(
      splitClauses('اشتري خبز، اتصل بأمي، وكلم الصيدلية الساعة 5 العصر'),
      ['اشتري خبز', 'اتصل بأمي', 'كلم الصيدلية الساعة 5 العصر'],
    );
    expect(
      splitClauses('الأحد زيارة المريض، والاثنين دوام'),
      ['الأحد زيارة المريض', 'الاثنين دوام'],
    );
  });

  test('English marker', () {
    expect(
      splitClauses(
        'Tomorrow at 2 pm call the bank and remind me to send the report',
      ),
      ['Tomorrow at 2 pm call the bank', 'remind me to send the report'],
    );
    expect(
      splitClauses(
        'Pay the electricity bill, and remind me on Friday to renew the passport',
      ),
      ['Pay the electricity bill', 'remind me on Friday to renew the passport'],
    );
  });

  test('a lone "and" is not a split point', () {
    expect(splitClauses('ملح وفلفل'), ['ملح وفلفل']);
    expect(splitClauses('لازم أشتري حليب وبيض وجبنة'), ['لازم أشتري حليب وبيض وجبنة']);
    for (final c in splitClauses('بدي أدفع القسط وأجدد الإقامة وأشتري خبز')) {
      expect(_words(c), greaterThanOrEqualTo(2), reason: c);
    }
  });

  test('a one-word piece joins its neighbour', () {
    expect(splitClauses('ملح، فلفل'), ['ملح فلفل']);
  });

  test('empty and separator-only input give no clauses', () {
    expect(splitClauses(''), isEmpty);
    expect(splitClauses('   '), isEmpty);
    expect(splitClauses('،،،'), isEmpty);
  });

  test('a huge input gives at most 20 clauses, fast', () {
    final sw = Stopwatch()..start();
    final clauses = splitClauses('اشتري خبز، ' * 1000);
    expect(clauses.length, lessThanOrEqualTo(20));
    expect(sw.elapsed.inSeconds, lessThan(2));
  });
}
