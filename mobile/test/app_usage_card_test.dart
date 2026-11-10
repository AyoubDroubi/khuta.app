import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/statistics/data/app_usage.dart';
import 'package:khuta/features/statistics/widgets/app_usage_card.dart';
import 'package:khuta/features/statistics/widgets/app_usage_source.dart';

import 'support/app_harness.dart';

class _FakeAppUsageSource implements AppUsageSource {
  _FakeAppUsageSource({
    required this.hasAccess,
    required this.summary,
    this.readError,
  });

  bool hasAccess;
  final AppUsageSummary summary;
  Object? readError;
  Completer<bool>? accessResult;
  Completer<bool>? settingsResult;
  int accessChecks = 0;
  int settingsOpens = 0;
  int reads = 0;

  @override
  Future<bool> hasUsageAccess() async {
    accessChecks++;
    final delayedResult = accessResult;
    if (delayedResult != null) return delayedResult.future;
    return hasAccess;
  }

  @override
  Future<bool> openUsageAccessSettings() async {
    settingsOpens++;
    final delayedResult = settingsResult;
    if (delayedResult != null) return delayedResult.future;
    return true;
  }

  @override
  Future<AppUsageSummary> readToday() async {
    reads++;
    if (readError case final error?) throw error;
    return summary;
  }
}

AppUsageSummary _summary() => AppUsageSummary(
  totalForeground: const Duration(hours: 2, minutes: 6),
  apps: [
    AppUsageEntry(
      packageName: 'mail.app',
      name: 'Mail',
      foreground: const Duration(minutes: 41),
    ),
    AppUsageEntry(
      packageName: 'maps.app',
      name: 'Maps',
      foreground: const Duration(hours: 1, minutes: 2),
    ),
  ],
);

void main() {
  useEmptyStore();

  testWidgets(
    'does not claim to read usage while checking permission before consent',
    (tester) async {
      final source = _FakeAppUsageSource(
        hasAccess: true,
        summary: _summary(),
      );
      final accessResult = Completer<bool>();
      source.accessResult = accessResult;

      await pumpScreen(
        tester,
        Scaffold(
          body: AppUsageCard(
            source: source,
            platform: TargetPlatform.android,
          ),
        ),
        settle: false,
      );

      expect(find.text('Reading today\'s app use…'), findsNothing);
      accessResult.complete(true);
      await tester.pumpAndSettle();

      expect(find.text('I agree, show today\'s app use'), findsOneWidget);
      expect(source.reads, 0);
    },
  );

  testWidgets(
    'requires this-session consent before reading an existing grant',
    (tester) async {
      final source = _FakeAppUsageSource(
        hasAccess: true,
        summary: _summary(),
      );

      await pumpScreen(
        tester,
        Scaffold(
          body: AppUsageCard(
            source: source,
            platform: TargetPlatform.android,
          ),
        ),
      );

      expect(find.text('I agree, show today\'s app use'), findsOneWidget);
      expect(source.reads, 0);

      await tester.tap(find.text('I agree, show today\'s app use'));
      await tester.pumpAndSettle();

      expect(source.reads, 1);
      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('Mail'), findsOneWidget);
      expect(find.text('1h 2m'), findsOneWidget);
      expect(find.text('2h 6m'), findsOneWidget);
    },
  );

  testWidgets(
    'opens Android access settings without reading when access is off',
    (tester) async {
      final source = _FakeAppUsageSource(
        hasAccess: false,
        summary: _summary(),
      );
      final settingsResult = Completer<bool>();
      source.settingsResult = settingsResult;

      await pumpScreen(
        tester,
        Scaffold(
          body: AppUsageCard(
            source: source,
            platform: TargetPlatform.android,
          ),
        ),
      );

      expect(find.text('I agree, show today\'s app use'), findsOneWidget);
      expect(source.reads, 0);
      expect(source.settingsOpens, 0);

      await tester.tap(find.text('I agree, show today\'s app use'));
      await tester.pumpAndSettle();

      expect(source.settingsOpens, 0);
      expect(source.reads, 0);
      expect(find.text('Open Usage Access settings'), findsOneWidget);

      await tester.tap(find.text('Open Usage Access settings'));
      await tester.pump();

      expect(source.settingsOpens, 1);
      expect(source.reads, 0);
      expect(find.text('Usage Access is off'), findsOneWidget);
      expect(find.text('Reading today\'s app use…'), findsNothing);

      settingsResult.complete(true);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reads only after Usage Access is granted and Statistics resumes',
    (tester) async {
      final source = _FakeAppUsageSource(
        hasAccess: false,
        summary: _summary(),
      );

      await pumpScreen(
        tester,
        Scaffold(
          body: AppUsageCard(
            source: source,
            platform: TargetPlatform.android,
          ),
        ),
      );
      await tester.tap(find.text('I agree, show today\'s app use'));
      await tester.pumpAndSettle();
      expect(source.reads, 0);
      await tester.tap(find.text('Open Usage Access settings'));
      await tester.pumpAndSettle();
      expect(source.reads, 0);

      source.hasAccess = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(source.reads, 1);
      expect(find.text('Maps'), findsOneWidget);
    },
  );

  testWidgets('reports unsupported platforms without calling Android APIs', (
    tester,
  ) async {
    final source = _FakeAppUsageSource(
      hasAccess: true,
      summary: _summary(),
    );

    await pumpScreen(
      tester,
      Scaffold(
        body: AppUsageCard(
          source: source,
          platform: TargetPlatform.iOS,
        ),
      ),
    );

    expect(
      find.text('App-use summaries are available on Android.'),
      findsOneWidget,
    );
    expect(source.accessChecks, 0);
    expect(source.reads, 0);
  });

  testWidgets('rechecks access after it is revoked during the session', (
    tester,
  ) async {
    final source = _FakeAppUsageSource(
      hasAccess: true,
      summary: _summary(),
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: AppUsageCard(
          source: source,
          platform: TargetPlatform.android,
        ),
      ),
    );
    await tester.tap(find.text('I agree, show today\'s app use'));
    await tester.pumpAndSettle();
    expect(source.reads, 1);

    source.hasAccess = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(source.reads, 1);
    expect(find.text('Usage Access is off'), findsOneWidget);
  });

  testWidgets('refreshes after resume while its card is scrolled offscreen', (
    tester,
  ) async {
    final source = _FakeAppUsageSource(
      hasAccess: true,
      summary: _summary(),
    );
    await pumpScreen(
      tester,
      ListView(
        children: [
          AppUsageCard(
            source: source,
            platform: TargetPlatform.android,
          ),
          for (var index = 0; index < 10; index++)
            SizedBox(height: 400, child: Text('Spacer $index')),
        ],
      ),
    );
    await tester.tap(find.text('I agree, show today\'s app use'));
    await tester.pumpAndSettle();
    expect(source.reads, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(source.reads, 2);
  });

  testWidgets('shows a recoverable query error and supports retry', (
    tester,
  ) async {
    final source = _FakeAppUsageSource(
      hasAccess: true,
      summary: _summary(),
      readError: StateError('query failed'),
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: AppUsageCard(
          source: source,
          platform: TargetPlatform.android,
        ),
      ),
    );
    await tester.tap(find.text('I agree, show today\'s app use'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t read app use right now.'), findsOneWidget);

    source.readError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(source.reads, 2);
    expect(find.text('Maps'), findsOneWidget);
  });

  testWidgets('renders an empty same-day summary without an app list', (
    tester,
  ) async {
    final source = _FakeAppUsageSource(
      hasAccess: true,
      summary: AppUsageSummary(
        totalForeground: const Duration(minutes: 32),
        apps: const [],
      ),
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: AppUsageCard(
          source: source,
          platform: TargetPlatform.android,
        ),
      ),
    );
    await tester.tap(find.text('I agree, show today\'s app use'));
    await tester.pumpAndSettle();

    expect(find.text('32m'), findsOneWidget);
    expect(
      find.text('No app-use data is available for today yet.'),
      findsOneWidget,
    );
    expect(find.text('Most used apps'), findsNothing);
  });

  test(
    'preserves all-app total while limiting the sorted list to five apps',
    () {
      final summary = AppUsageSummary.fromPlatform({
        'totalDurationMs': 2400000,
        'apps': [
          for (var index = 0; index < 7; index++)
            {
              'packageName': 'app.$index',
              'name': 'App $index',
              'durationMs': (index + 1) * 60000,
            },
        ],
      });

      expect(summary.apps, hasLength(5));
      expect(summary.apps.first.packageName, 'app.6');
      expect(summary.apps.last.packageName, 'app.2');
      expect(summary.totalForeground, const Duration(minutes: 40));
    },
  );
}
