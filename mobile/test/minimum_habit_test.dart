import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/services/backup_service.dart';

final _today = AppClock.today();

HabitMinimumTargetVersion _v(DateTime from, double min, {int order = 0}) =>
    HabitMinimumTargetVersion(
      effectiveDate: from.dayKey,
      minimum: min,
      recordedAt: DateTime.utc(2026, 1, 1, 0, order),
    );

Habit _habit({
  double target = 10,
  List<HabitMinimumTargetVersion> minimums = const [],
  Map<DateTime, double> counts = const {},
  HabitKind kind = HabitKind.positive,
}) =>
    Habit(
      id: 'h',
      name: 'h',
      color: const Color(0xFF94492F),
      order: 0,
      kind: kind,
      perDayTarget: target,
      createdAt: _today.addDays(-60),
      minimumTargetVersions: minimums,
      completions: {
        for (final e in counts.entries)
          e.key.dayKey: Completion(date: e.key.dayKey, count: e.value, hour: 9),
      },
    );

void main() {
  test('without a minimum the full target is required (unchanged behaviour)', () {
    final h = _habit(counts: {_today: 5});
    expect(h.requiredOn(_today), 10);
    expect(h.isCompletedOn(_today), isFalse);
  });

  test('a minimum completes the day, the full target stays separate', () {
    final h = _habit(
      minimums: [_v(_today.addDays(-30), 3)],
      counts: {_today: 3},
    );
    expect(h.isCompletedOn(_today), isTrue);
    expect(h.isFullTargetOn(_today), isFalse);
  });

  test('below the minimum is not done', () {
    final h = _habit(
      minimums: [_v(_today.addDays(-30), 3)],
      counts: {_today: 2},
    );
    expect(h.isCompletedOn(_today), isFalse);
  });

  test('versions apply by effective date; earlier days keep the old rule', () {
    final h = _habit(
      minimums: [_v(_today.addDays(-10), 5)],
      counts: {_today.addDays(-20): 3, _today: 5},
    );
    expect(h.isCompletedOn(_today.addDays(-20)), isFalse);
    expect(h.isCompletedOn(_today), isTrue);
  });

  test('same effective date: the latest recorded version wins', () {
    final day = _today.addDays(-5);
    final h = _habit(minimums: [_v(day, 2, order: 1), _v(day, 4, order: 2)]);
    expect(h.minimumVersionFor(_today), 4);
  });

  test('a minimum above the full target is capped', () {
    final h = _habit(minimums: [_v(_today.addDays(-5), 50)]);
    expect(h.requiredOn(_today), 10);
  });

  test('negative habits ignore minimums', () {
    final h = _habit(
      kind: HabitKind.negative,
      target: 1,
      minimums: [_v(_today.addDays(-5), 1)],
    );
    expect(h.requiredOn(_today), h.effectiveTarget);
  });

  test('minimum versions survive a map round trip; absent key loads empty', () {
    final h = _habit(minimums: [_v(_today.addDays(-5), 3)]);
    final back = Habit.fromMap(h.toMap());
    expect(back.minimumTargetVersions.single.minimum, 3);
    expect(back.minimumTargetVersions.single.effectiveDate,
        _today.addDays(-5).dayKey);

    final plain = _habit().toMap()..remove('minimumTargetVersions');
    expect(plain.containsKey('minimumTargetVersions'), isFalse);
    expect(Habit.fromMap(plain).minimumTargetVersions, isEmpty);
  });

  test('totals and streak count minimum-completed days', () {
    final h = _habit(
      minimums: [_v(_today.addDays(-30), 3)],
      counts: {
        _today: 3,
        _today.addDays(-1): 4,
        _today.addDays(-2): 10,
      },
    );
    expect(h.currentStreak, 3);
  });

  test('backup keeps minimum versions; an old backup without them loads', () {
    String backup(Habit h) => jsonEncode({
          'app': 'streak',
          'version': 1,
          'habits': [h.toMap()],
          'notes': [],
          'focus': [],
          'todos': [],
          'categories': [],
        });

    final withMin = _habit(minimums: [_v(_today.addDays(-5), 3)]);
    final restored = BackupService.parse(backup(withMin)).habits.single;
    expect(restored.minimumTargetVersions.single.minimum, 3);
    expect(restored.requiredOn(_today), 3);

    final old = _habit(counts: {_today: 10});
    final oldRestored = BackupService.parse(backup(old)).habits.single;
    expect(oldRestored.minimumTargetVersions, isEmpty);
    expect(oldRestored.isCompletedOn(_today), isTrue);
  });
}
