import 'package:khuta/features/daily_plan/data/daily_plan.dart';

class DailyPlanOutcome {
  const DailyPlanOutcome({
    required this.date,
    required this.plannedCount,
    required this.completedCount,
  });

  final String date;
  final int plannedCount;
  final int completedCount;

  bool get isEmpty => plannedCount == 0;
  bool get isComplete => plannedCount > 0 && completedCount == plannedCount;

  double get progress =>
      plannedCount == 0 ? 0 : completedCount / plannedCount;

  factory DailyPlanOutcome.fromCompletionStates(
    DailyPlan plan,
    Iterable<bool> completionStates,
  ) {
    final states = completionStates.toList(growable: false);
    if (states.length != plan.items.length) {
      throw ArgumentError.value(
        states.length,
        'completionStates',
        'Completion state count must match the Daily Plan item count.',
      );
    }

    return DailyPlanOutcome(
      date: plan.date,
      plannedCount: plan.items.length,
      completedCount: states.where((completed) => completed).length,
    );
  }
}
