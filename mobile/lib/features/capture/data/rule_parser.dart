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

class _Draft {
  _Draft({
    required this.note,
    required this.title,
    required this.when,
    required this.priority,
    required this.project,
    required this.tags,
    required this.askedToRemind,
  });

  final bool note;
  final String title;
  WhenMatch when;
  TodoPriority priority;
  final String project;
  final List<String> tags;
  final bool askedToRemind;
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

    final drafts = <_Draft>[];
    // A clause with nothing but importance, day or time words ("مهم كتير",
    // "يوم الخميس") is not an item. It fills the gaps of the item before it,
    // or, if it comes first, of the item after it.
    WhenMatch? carryWhen;
    var carryPriority = TodoPriority.none;

    for (final clause in splitClauses(stripMarks(input))) {
      final folded = foldLetters(clause);
      final when = findWhen(folded);
      final title = buildTitle(clause, when.spans);
      final priority = findPriority(folded);

      if (!_hasWords(title)) {
        if (drafts.isNotEmpty) {
          final last = drafts.last;
          last.when = last.when.merge(when);
          if (!last.note && last.priority == TodoPriority.none) {
            last.priority = priority;
          }
        } else {
          carryWhen = carryWhen == null ? when : carryWhen.merge(when);
          if (carryPriority == TodoPriority.none) carryPriority = priority;
        }
        continue;
      }
      if (drafts.length >= maxClauses) continue;

      final note = isNote(folded);
      final known = matchKnown(folded, projects: projects, labels: labels);
      var merged = when;
      var itemPriority = note ? TodoPriority.none : priority;
      if (carryWhen != null) {
        merged = when.merge(carryWhen);
        carryWhen = null;
        if (!note && itemPriority == TodoPriority.none) {
          itemPriority = carryPriority;
        }
        carryPriority = TodoPriority.none;
      }
      drafts.add(_Draft(
        note: note,
        title: title,
        when: merged,
        priority: itemPriority,
        project: known.project,
        tags: known.tags,
        askedToRemind: !note && asksToRemind(folded),
      ));
    }

    return [
      for (final d in drafts) _build(d, today: today, now: now),
    ];
  }

  ProposedItem _build(
    _Draft d, {
    required DateTime today,
    required DateTime now,
  }) {
    final resolved = resolveWhen(d.when, today: today, now: now);
    return ProposedItem(
      kind: d.note ? ProposedKind.note : ProposedKind.task,
      title: d.title,
      day: resolved.day,
      minutes: resolved.minutes,
      priority: d.note ? TodoPriority.none : d.priority,
      project: d.project,
      tags: d.tags,
      askedToRemind: d.askedToRemind,
      timePassed: resolved.timePassed,
    );
  }
}
