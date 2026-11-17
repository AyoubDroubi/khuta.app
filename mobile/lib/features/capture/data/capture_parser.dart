import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';

/// Turns one typed sentence into proposed items. Async so a model-backed
/// parser can implement it later.
///
/// [now] is the wall clock (`AppClock.wallNow()`); [today] is the logical day
/// (`AppClock.today()`). [projects] and [labels] are the existing tags the text
/// may name; the parser never creates one.
abstract interface class CaptureParser {
  Future<List<ProposedItem>> parse(
    String text, {
    required DateTime now,
    required DateTime today,
    List<TodoTag> projects = const [],
    List<TodoTag> labels = const [],
  });
}
