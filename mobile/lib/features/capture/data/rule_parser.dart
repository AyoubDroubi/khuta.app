import 'package:khuta/features/capture/data/capture_normalize.dart';
import 'package:khuta/features/capture/data/capture_parser.dart';
import 'package:khuta/features/capture/data/capture_split.dart';
import 'package:khuta/features/capture/data/capture_when.dart';
import 'package:khuta/features/capture/data/capture_words.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';

const maxCaptureInput = 2000;

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _hasWords(String title) => _wordChar.hasMatch(title);

ProposedItem _absorb(ProposedItem item, String folded, ResolvedWhen when) {
  final priority = item.kind == ProposedKind.task &&
          item.priority == TodoPriority.none
      ? findPriority(folded)
      : item.priority;
  return item.copyWith(
    priority: priority,
    day: item.day == null ? when.day : null,
    minutes: item.minutes == null ? when.minutes : null,
    timePassed: item.timePassed || when.timePassed,
  );
}

/// The always-on, on-device parser: no model, no network, no state.
class RuleParser implements CaptureParser {
  const RuleParser();

  @override
  Future<List<ProposedItem>> parse(
    String text, {
    required DateTime now,
    required DateTime today,
    List<TodoTag> projects = const [],
    List<TodoTag> labels = const [],
  }) async {
    final input = text.length > maxCaptureInput
        ? text.substring(0, maxCaptureInput)
        : text;
    final items = <ProposedItem>[];
    for (final clause in splitClauses(stripMarks(input))) {
      final folded = foldLetters(clause);
      final when = findWhen(folded);
      final resolved = resolveWhen(when, today: today, now: now);
      final title = buildTitle(clause, when.spans);
      if (!_hasWords(title)) {
        // A clause with only importance, day or time words ("مهم كتير")
        // belongs to the item before it.
        if (items.isNotEmpty) {
          items[items.length - 1] = _absorb(items.last, folded, resolved);
        }
        continue;
      }
      final note = isNote(folded);
      final known = matchKnown(folded, projects: projects, labels: labels);
      items.add(ProposedItem(
        kind: note ? ProposedKind.note : ProposedKind.task,
        title: title,
        day: resolved.day,
        minutes: resolved.minutes,
        priority: note ? TodoPriority.none : findPriority(folded),
        project: known.project,
        tags: known.tags,
        askedToRemind: !note && asksToRemind(folded),
        timePassed: resolved.timePassed,
      ));
      if (items.length >= maxClauses) break;
    }
    return items;
  }
}
