import 'package:khuta/features/todos/data/todo.dart';

enum ProposedKind { task, note }

/// One thing the parser found in a sentence, before anything is saved.
///
/// `project` and `tags` hold [TodoTag] ids (what `Todo` stores), `''` and
/// empty when none. A reminder is a task with a time, so there is no reminder
/// kind: [askedToRemind] records that the person said "remind me".
class ProposedItem {
  const ProposedItem({
    required this.kind,
    required this.title,
    this.day,
    this.minutes,
    this.priority = TodoPriority.none,
    this.project = '',
    this.tags = const [],
    this.askedToRemind = false,
    this.timePassed = false,
  });

  final ProposedKind kind;
  final String title;
  final DateTime? day;
  final int? minutes;
  final TodoPriority priority;
  final String project;
  final List<String> tags;
  final bool askedToRemind;
  final bool timePassed;

  bool get needsTime =>
      kind == ProposedKind.task && askedToRemind && minutes == null;

  ProposedItem copyWith({
    ProposedKind? kind,
    String? title,
    DateTime? day,
    int? minutes,
    TodoPriority? priority,
    String? project,
    List<String>? tags,
    bool? askedToRemind,
    bool? timePassed,
    bool clearDay = false,
    bool clearMinutes = false,
  }) =>
      ProposedItem(
        kind: kind ?? this.kind,
        title: title ?? this.title,
        day: clearDay ? null : (day ?? this.day),
        minutes: clearMinutes ? null : (minutes ?? this.minutes),
        priority: priority ?? this.priority,
        project: project ?? this.project,
        tags: tags ?? this.tags,
        askedToRemind: askedToRemind ?? this.askedToRemind,
        timePassed: timePassed ?? this.timePassed,
      );
}
