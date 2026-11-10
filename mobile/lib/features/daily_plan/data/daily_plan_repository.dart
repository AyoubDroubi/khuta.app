import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';

class DailyPlanRepository {
  const DailyPlanRepository();

  List<DailyPlan> readAll() => LocalStore.readDailyPlans();

  DailyPlan? read(String date) => LocalStore.readDailyPlan(date);

  Future<void> save(DailyPlan plan) => LocalStore.writeDailyPlan(plan);
}
