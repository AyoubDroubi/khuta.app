import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/goals/data/goal.dart';

class GoalRepository {
  const GoalRepository();

  List<Goal> readAll() => LocalStore.readGoals();

  Future<void> save(Goal goal) => LocalStore.writeGoal(goal);

  Future<void> remove(String id) => LocalStore.removeGoal(id);
}
