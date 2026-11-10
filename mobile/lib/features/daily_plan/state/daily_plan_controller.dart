import 'package:flutter/foundation.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/daily_plan/data/daily_plan_repository.dart';

class DailyPlanController extends ChangeNotifier {
  DailyPlanController({DailyPlanRepository? repository})
      : _repository = repository ?? const DailyPlanRepository() {
    reload();
  }

  final DailyPlanRepository _repository;
  final Map<String, DailyPlan> _plans = {};

  DailyPlan forDate(DateTime date) =>
      _plans[date.dayKey] ?? DailyPlan(date: date.dayKey);

  DailyPlan get today => forDate(AppClock.today());

  void reload() {
    _plans
      ..clear()
      ..addEntries(
        _repository.readAll().map((plan) => MapEntry(plan.date, plan)),
      );
    notifyListeners();
  }

  Future<void> add(DateTime date, DailyPlanItem item) async {
    final plan = forDate(date);
    if (plan.items.length >= DailyPlan.maxItems ||
        plan.items.any((existing) => existing.key == item.key)) {
      return;
    }
    await _save(
      plan.copyWith(
        items: [...plan.items, item],
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> remove(DateTime date, String itemKey) async {
    final plan = forDate(date);
    await _save(
      plan.copyWith(
        items: plan.items
            .where((item) => item.key != itemKey)
            .toList(growable: false),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> move(DateTime date, int fromIndex, int toIndex) async {
    final plan = forDate(date);
    if (fromIndex < 0 ||
        fromIndex >= plan.items.length ||
        toIndex < 0 ||
        toIndex >= plan.items.length ||
        fromIndex == toIndex) {
      return;
    }

    final items = [...plan.items];
    final item = items.removeAt(fromIndex);
    items.insert(toIndex, item);
    await _save(
      plan.copyWith(
        items: items,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> reorder(DateTime date, int oldIndex, int newIndex) async {
    final plan = forDate(date);
    if (oldIndex < 0 ||
        oldIndex >= plan.items.length ||
        newIndex < 0 ||
        newIndex > plan.items.length) {
      return;
    }

    final items = [...plan.items];
    if (newIndex > oldIndex) newIndex--;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    await _save(
      plan.copyWith(
        items: items,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _save(DailyPlan plan) async {
    if (plan.items.length > DailyPlan.maxItems) {
      throw StateError('Daily Plan cannot contain more than 3 priorities.');
    }

    await _repository.save(plan);
    _plans[plan.date] = plan;
    notifyListeners();
  }
}
