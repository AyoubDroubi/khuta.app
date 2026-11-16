/// Importance, type words, known tag names and title building for one clause.
///
/// `findPriority`, `asksToRemind`, `isNote` and `matchKnown` take text already
/// folded with `foldLetters`; the keyword tables are written in folded
/// spelling. `buildTitle` takes the typed (unfolded) clause.
library;

import 'package:khuta/features/capture/data/capture_normalize.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';

const _letters = r'؀-ۿa-z0-9';

String _w(String body) => '(?<![$_letters])(?:$body)(?![$_letters])';

const _intensifier = r'(?:\s+(?:جدا|كتير|كثير|very))?';

final _low = RegExp(
  _w(r'مش\s+مهم|مو\s+مهم|غير\s+مهم|لو\s+فضيت|لو\s+فاضي|not\s+important'),
);
final _high = RegExp('${_w('مهم|ضروري|ضروره|عاجل|urgent|important|asap')}'
    '$_intensifier');
final _remind = RegExp(_w('ذكرني|نبهني|remind\\s+me'));
final _remindCut = RegExp(
  '${_w(r'ذكرني|نبهني|remind\s+me')}(?:\\s+(?:on|at|to))*',
);
final _note = RegExp(_w(r'ملاحظه|note|كل\s+ما\s+اتذكر|كلما\s+تذكرت'));
final _noteCut = RegExp(
  '(?:${_w('سجل')}\\s+)?${_w(r'ملاحظه|note|كل\s+ما\s+اتذكر|كلما\s+تذكرت')}',
);

final _filler = RegExp(
  '^\\s*(?:و\\s*)?(?:بدي|بدنا|لازم|عندي|محتاج|i\\s+need\\s+to|i\\s+have\\s+to|'
  'need\\s+to|i\\s+want\\s+to)(?![$_letters])\\s*',
);
final _trailing = RegExp(
  '\\s+(?:وهاد|وهذا|وهاي|و|بس|ثم|and)\\s*\$',
);
final _edges = RegExp(r'^[\s:،,.;؛!؟?\-]+|[\s:،,.;؛!؟?\-]+$');

/// Low wins over high; no importance word means none.
TodoPriority findPriority(String folded) {
  if (_low.hasMatch(folded)) return TodoPriority.low;
  if (_high.hasMatch(folded)) return TodoPriority.high;
  return TodoPriority.none;
}

bool asksToRemind(String folded) => _remind.hasMatch(folded);

bool isNote(String folded) => _note.hasMatch(folded);

/// The id of the first project whose name occurs in [folded] and the ids of
/// every label whose name occurs. Never produces an id that does not exist.
({String project, List<String> tags}) matchKnown(
  String folded, {
  required List<TodoTag> projects,
  required List<TodoTag> labels,
}) {
  bool named(TodoTag tag) {
    final name = foldLetters(tag.name.trim());
    if (name.isEmpty) return false;
    return RegExp(_w(RegExp.escape(name))).hasMatch(folded);
  }

  final project = projects.where(named).map((t) => t.id).firstOrNull ?? '';
  final tags = [for (final l in labels) if (named(l)) l.id];
  return (project: project, tags: tags);
}

/// The item's title: [clause] without the [cutSpans] (indices into the folded
/// clause, from `findWhen`), importance words, type words and leading fillers.
/// Returns `''` when nothing is left.
String buildTitle(String clause, List<(int, int)> cutSpans) {
  final folded = foldLetters(clause);
  final ranges = <(int, int)>[...cutSpans];
  for (final rx in [_low, _high, _remindCut, _noteCut]) {
    for (final m in rx.allMatches(folded)) {
      ranges.add((m.start, m.end));
    }
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));

  final out = StringBuffer();
  var cursor = 0;
  for (final (start, end) in ranges) {
    if (end <= cursor) continue;
    if (start > cursor) out.write(clause.substring(cursor, start));
    out.write(' ');
    cursor = end;
  }
  if (cursor < clause.length) out.write(clause.substring(cursor));

  var title = out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  while (true) {
    final m = _filler.firstMatch(foldLetters(title));
    if (m == null || m.end == 0) break;
    title = title.substring(m.end);
  }
  while (true) {
    final m = _trailing.firstMatch(foldLetters(title));
    if (m == null) break;
    title = title.substring(0, m.start);
  }
  return title.replaceAll(_edges, '').trim();
}
