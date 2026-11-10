import 'package:flutter/foundation.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/journeys/data/journey_repository.dart';
import 'package:uuid/uuid.dart';

class JourneysController extends ChangeNotifier {
  JourneysController({JourneyRepository? repository})
      : _repository = repository ?? const JourneyRepository() {
    _journeys = _repository.readAll();
    _sort();
  }

  final JourneyRepository _repository;
  static const _uuid = Uuid();
  late List<Journey> _journeys;

  List<Journey> get all => List.unmodifiable(_journeys);

  Journey? byId(String id) {
    for (final journey in _journeys) {
      if (journey.id == id) return journey;
    }
    return null;
  }

  void reload() {
    _journeys = _repository.readAll();
    _sort();
    notifyListeners();
  }

  Future<Journey> create({
    required String title,
    String description = '',
    String icon = 'route',
    String coverPath = '',
    String startDate = '',
    String targetDate = '',
    JourneyStatus status = JourneyStatus.planned,
    int? focusTargetMinutes,
    List<JourneyMilestone> milestones = const [],
    List<String> habitIds = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final journey = Journey(
      id: _uuid.v4(),
      title: title.trim(),
      description: description.trim(),
      icon: icon.trim().isEmpty ? 'route' : icon.trim(),
      coverPath: coverPath.trim(),
      startDate: startDate,
      targetDate: targetDate,
      status: status,
      focusTargetMinutes: focusTargetMinutes,
      milestones: milestones,
      habitIds: habitIds.toSet().toList(),
      createdAt: now,
      updatedAt: now,
      completedAt: status == JourneyStatus.completed ? now : null,
    );
    _validateJourney(journey);
    _journeys.add(journey);
    _sort();
    await _repository.save(journey);
    notifyListeners();
    return journey;
  }

  Future<void> save(Journey journey) async {
    _validateJourney(journey);
    final index = _journeys.indexWhere((item) => item.id == journey.id);
    final now = DateTime.now().toUtc();
    Journey normalized = journey.copyWith(updatedAt: now);
    final wasCompleted =
        index >= 0 && _journeys[index].status == JourneyStatus.completed;
    final isCompleted = normalized.status == JourneyStatus.completed;
    if (!wasCompleted && isCompleted && normalized.completedAt == null) {
      normalized = normalized.copyWith(completedAt: now);
    } else if (wasCompleted && !isCompleted) {
      normalized = normalized.copyWith(clearCompletedAt: true);
    }

    if (index == -1) {
      _journeys.add(normalized);
    } else {
      _journeys[index] = normalized;
    }
    _sort();
    await _repository.save(normalized);
    notifyListeners();
  }

  Future<void> toggleMilestone(String journeyId, String milestoneId) async {
    final journey = byId(journeyId);
    if (journey == null) return;
    final now = DateTime.now().toUtc();
    final milestones = [
      for (final item in journey.milestones)
        if (item.id == milestoneId)
          item.completed
              ? item.copyWith(completed: false, clearCompletedAt: true)
              : item.copyWith(completed: true, completedAt: now)
        else
          item,
    ];
    await save(journey.copyWith(milestones: milestones));
  }

  Future<void> remove(String id) async {
    _journeys.removeWhere((item) => item.id == id);
    await _repository.remove(id);
    notifyListeners();
  }

  JourneyMilestone newMilestone(String title, int order) => JourneyMilestone(
        id: _uuid.v4(),
        title: title.trim(),
        completed: false,
        order: order,
      );

  static void _validateJourney(Journey journey) {
    final titleLength = journey.title.trim().length;
    if (titleLength < 1 || titleLength > 160) {
      throw ArgumentError('Journey title must contain between 1 and 160 characters.');
    }
    if (journey.description.trim().length > 4000) {
      throw ArgumentError('Journey description is too long.');
    }
    final focusTarget = journey.focusTargetMinutes;
    if (focusTarget != null && (focusTarget < 0 || focusTarget > 525600)) {
      throw ArgumentError('Journey focus target is invalid.');
    }

    DateTime? parseOptional(String value) {
      if (value.trim().isEmpty) return null;
      return parseDayKey(value);
    }

    final start = parseOptional(journey.startDate);
    final target = parseOptional(journey.targetDate);
    if (start != null && target != null && target.isBefore(start)) {
      throw ArgumentError('Journey target date cannot be before its start date.');
    }

    if (journey.milestones.any(
      (item) => item.title.trim().isEmpty || item.title.trim().length > 240,
    )) {
      throw ArgumentError('Journey milestone title is invalid.');
    }
    if (journey.habitIds.toSet().length != journey.habitIds.length) {
      throw ArgumentError('Journey habit links must be unique.');
    }
  }

  void _sort() {
    _journeys.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      if (byStatus != 0) return byStatus;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
}
