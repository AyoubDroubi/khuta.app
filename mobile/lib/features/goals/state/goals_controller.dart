import 'package:flutter/foundation.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/goals/data/goal_repository.dart';
import 'package:uuid/uuid.dart';

class GoalsController extends ChangeNotifier {
  GoalsController({GoalRepository? repository})
      : _repository = repository ?? const GoalRepository() {
    _goals = _repository.readAll();
    _sort();
  }

  final GoalRepository _repository;
  static const _uuid = Uuid();
  late List<Goal> _goals;

  List<Goal> get all => List.unmodifiable(_goals);
  List<Goal> get active =>
      List.unmodifiable(_goals.where((goal) => !goal.isArchived));
  List<Goal> get archived =>
      List.unmodifiable(_goals.where((goal) => goal.isArchived));
  List<Goal> get roots => List.unmodifiable(
        _goals.where((goal) =>
            !goal.isArchived &&
            (goal.parentGoalId == null || byId(goal.parentGoalId!) == null)),
      );

  Goal? byId(String id) {
    for (final goal in _goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  List<Goal> childrenOf(String goalId) => List.unmodifiable(
        _goals.where((goal) =>
            !goal.isArchived && goal.parentGoalId == goalId).toList()
          ..sort(_compare),
      );

  bool canUseParent(String goalId, String? parentGoalId) {
    if (parentGoalId == null || parentGoalId.isEmpty) return true;
    if (goalId == parentGoalId) return false;
    var current = byId(parentGoalId);
    final visited = <String>{};
    while (current != null) {
      if (!visited.add(current.id) || current.id == goalId) return false;
      final parent = current.parentGoalId;
      if (parent == null || parent.isEmpty) return true;
      current = byId(parent);
    }
    return true;
  }

  void reload() {
    _goals = _repository.readAll();
    _sort();
    notifyListeners();
  }

  Future<Goal> create({
    required String title,
    String description = '',
    String targetDate = '',
    String? parentGoalId,
    List<GoalSourceLink> sources = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final goal = Goal(
      id: _uuid.v4(),
      title: title.trim(),
      description: description.trim(),
      targetDate: targetDate.trim(),
      parentGoalId: parentGoalId,
      sources: _dedupeSources(sources),
      createdAt: now,
      updatedAt: now,
    );
    _validate(goal);
    _goals.add(goal);
    _sort();
    await _repository.save(goal);
    notifyListeners();
    return goal;
  }

  Future<void> save(Goal goal) async {
    _validate(goal);
    final index = _goals.indexWhere((item) => item.id == goal.id);
    final normalized = goal.copyWith(updatedAt: DateTime.now().toUtc());
    if (index == -1) {
      _goals.add(normalized);
    } else {
      _goals[index] = normalized;
    }
    _sort();
    await _repository.save(normalized);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    if (_goals.any((goal) => goal.parentGoalId == id)) {
      throw StateError('Move or delete subgoals before deleting this goal.');
    }
    _goals.removeWhere((goal) => goal.id == id);
    await _repository.remove(id);
    notifyListeners();
  }

  Future<void> setState(String id, GoalState state) async {
    final goal = byId(id);
    if (goal == null) return;
    await save(goal.copyWith(state: state));
  }

  void _validate(Goal goal) {
    final titleLength = goal.title.trim().length;
    if (titleLength < 1 || titleLength > 160) {
      throw ArgumentError('Goal title must contain between 1 and 160 characters.');
    }
    if (goal.description.trim().length > 4000) {
      throw ArgumentError('Goal description is too long.');
    }
    if (!canUseParent(goal.id, goal.parentGoalId)) {
      throw ArgumentError('Goal hierarchy cannot contain a cycle.');
    }
    if (goal.parentGoalId != null && byId(goal.parentGoalId!) == null) {
      throw ArgumentError('Parent goal is unavailable.');
    }
    final keys = <String>{};
    for (final source in goal.sources) {
      if (source.sourceId.trim().isEmpty) {
        throw ArgumentError('Goal source ID is required.');
      }
      if (!keys.add('${source.type.index}:${source.sourceId}')) {
        throw ArgumentError('A source can only be linked once per goal.');
      }
    }
  }

  static List<GoalSourceLink> _dedupeSources(
    Iterable<GoalSourceLink> sources,
  ) {
    final result = <GoalSourceLink>[];
    final seen = <String>{};
    for (final source in sources) {
      final key = '${source.type.index}:${source.sourceId}';
      if (seen.add(key)) result.add(source);
    }
    return result;
  }

  void _sort() => _goals.sort(_compare);

  static int _compare(Goal a, Goal b) {
    final byState = a.state.index.compareTo(b.state.index);
    if (byState != 0) return byState;
    return b.updatedAt.compareTo(a.updatedAt);
  }
}
