import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/calendar/calendar_display.dart';
import 'package:khuta/core/calendar/hijri_schedule.dart';
import 'package:khuta/features/focus/widgets/focus_backgrounds.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

import 'support/app_harness.dart';

// every setting is written to the store
// and read back by a fresh controller, so a restart keeps it.
class _Case {
  const _Case(this.name, this.set, this.get, this.value);

  final String name;
  final Future<void> Function(SettingsController c) set;
  final Object? Function(SettingsController c) get;
  final Object? value;
}

void main() {
  useEmptyStore();
  tearDown(() => HijriSchedule.adjust = 0);

  final cases = <_Case>[
    _Case('currency', (c) => c.setCurrency('€'), (c) => c.currency, '€'),
    _Case('accentColor', (c) => c.setAccentColor(const Color(0xFF123456)), (c) => c.accentColor, const Color(0xFF123456)),
    _Case('heatmapRolling', (c) => c.setHeatmapRolling(true), (c) => c.heatmapRolling, true),
    _Case('heatmapPath', (c) => c.setHeatmapPath(true), (c) => c.heatmapPath, true),
    _Case('heatmapMode', (c) => c.setHeatmapMode(2), (c) => c.heatmapMode, 2),
    _Case('startView', (c) => c.setStartView(2), (c) => c.startView, 2),
    _Case('planningEnabled', (c) => c.setPlanningEnabled(true), (c) => c.planningEnabled, true),
    _Case('cardActivity', (c) => c.setCardActivity(true), (c) => c.cardActivity, true),
    _Case('viewSwitcher', (c) => c.setViewSwitcher(true), (c) => c.viewSwitcher, true),
    _Case('compactCards', (c) => c.setCompactCards(true), (c) => c.compactCards, true),
    _Case('focusEnabled', (c) => c.setFocusEnabled(false), (c) => c.focusEnabled, false),
    _Case('focusClockStyle', (c) => c.setFocusClockStyle(2), (c) => c.focusClockStyle, 2),
    _Case('focusScene', (c) => c.setFocusScene(kFirstVideoScene), (c) => c.focusScene, kFirstVideoScene),
    _Case('focusDailyGoal', (c) => c.setFocusDailyGoal(90), (c) => c.focusDailyGoal, 90),
    _Case('focusKeepAwake', (c) => c.setFocusKeepAwake(false), (c) => c.focusKeepAwake, false),
    _Case('focusLeadIn', (c) => c.setFocusLeadIn(false), (c) => c.focusLeadIn, false),
    _Case('focusHold', (c) => c.setFocusHold(true), (c) => c.focusHold, true),
    _Case('appLockDelay', (c) => c.setAppLockDelay(30), (c) => c.appLockDelay, 30),
    _Case('readableCopy', (c) => c.setReadableCopy(true), (c) => c.readableCopy, true),
    _Case('notesEnabled', (c) => c.setNotesEnabled(false), (c) => c.notesEnabled, false),
    _Case('islandEnabled', (c) => c.setIslandEnabled(false), (c) => c.islandEnabled, false),
    _Case('trackingOption', (c) => c.setTrackingOption(true), (c) => c.trackingOption, true),
    _Case('showTodayProgress', (c) => c.setShowTodayProgress(false), (c) => c.showTodayProgress, false),
    _Case('quietWhenDone', (c) => c.setQuietWhenDone(false), (c) => c.quietWhenDone, false),
    _Case('difficultyOption', (c) => c.setDifficultyOption(true), (c) => c.difficultyOption, true),
    _Case('quoteSource', (c) => c.setQuoteSource(1), (c) => c.quoteSource, 1),
    _Case('appStyle', (c) => c.setAppStyle(2), (c) => c.appStyle, 2),
    _Case('sortCompletedLast', (c) => c.setSortCompletedLast(true), (c) => c.sortCompletedLast, true),
    _Case('todayOnly', (c) => c.setTodayOnly(true), (c) => c.todayOnly, true),
    _Case('language', (c) => c.setLanguage('ar'), (c) => c.localeCode, 'ar'),
    _Case('themeMode', (c) => c.setThemeMode(ThemeMode.dark), (c) => c.themeMode, ThemeMode.dark),
    _Case('calendarMode', (c) => c.setCalendarMode(CalendarMode.hijriGregorian), (c) => c.calendarMode, CalendarMode.hijriGregorian),
    _Case('hijriAdjust', (c) => c.setHijriAdjust(-2), (c) => c.hijriAdjust, -2),
    _Case('weekStart', (c) => c.setWeekStart(6), (c) => c.weekStart, 6),
    _Case('appBackground', (c) => c.setAppBackground(3), (c) => c.appBackground, 3),
    _Case('checkStyle', (c) => c.setCheckStyle(1), (c) => c.checkStyle, 1),
    _Case('profileName', (c) => c.setProfileName('Ayoub'), (c) => c.profileName, 'Ayoub'),
    _Case('widgetOpacity', (c) => c.setWidgetOpacity(40), (c) => c.widgetOpacity, 40),
    _Case('widgetBorder', (c) => c.setWidgetBorder(true), (c) => c.widgetBorder, true),
    _Case('onboardingDone', (c) => c.completeOnboarding(), (c) => c.onboardingDone, true),
  ];

  for (final c in cases) {
    test('${c.name} is stored and survives a restart', () async {
      final first = SettingsController();
      await c.set(first);
      expect(c.get(first), c.value, reason: 'in memory');
      final restarted = SettingsController();
      expect(c.get(restarted), c.value, reason: 'after a restart');
    });
  }

  test('a saved retired image scene (1–6) loads as the plain scene 0', () async {
    await SettingsController().setFocusScene(3);
    expect(SettingsController().focusScene, 0);
  });

  test('a fresh install starts with the documented defaults', () {
    final c = SettingsController();
    expect(c.onboardingDone, isFalse);
    expect(c.calendarMode, CalendarMode.gregorian);
    expect(c.hijriAdjust, 0);
    expect(c.weekStart, 1);
    expect(c.appStyle, 0);
    expect(c.accentColor.toARGB32(), 0xFF94492F);
  });

  test('the Hijri adjustment is clamped to −2…+2 and feeds the schedule value', () async {
    final c = SettingsController();
    await c.setHijriAdjust(9);
    expect(c.hijriAdjust, 2);
    expect(HijriSchedule.adjust, 2);
    await c.setHijriAdjust(-9);
    expect(c.hijriAdjust, -2);
    expect(HijriSchedule.adjust, -2);
  });

  test('a restarted controller sets the schedule adjustment from the store', () async {
    await SettingsController().setHijriAdjust(1);
    HijriSchedule.adjust = 0;
    SettingsController();
    expect(HijriSchedule.adjust, 1);
  });

  group('custom quotes', () {
    test('add, edit and remove are stored', () async {
      final c = SettingsController();
      await c.addCustomQuote('One');
      await c.addCustomQuote('Two');
      await c.editCustomQuote(0, 'Uno');
      await c.removeCustomQuote(1);
      expect(c.customQuotes, ['Uno']);
      expect(SettingsController().customQuotes, ['Uno']);
    });
  });

  group('focus lists', () {
    test('hidden scenes and tracks can be hidden and restored', () async {
      final c = SettingsController();
      await c.hideScene(2);
      await c.hideTrack('rain');
      expect(c.hiddenScenes, [2]);
      expect(c.hiddenTracks, ['rain']);
      expect(SettingsController().hiddenScenes, [2]);
      await c.restoreScenes();
      await c.restoreTracks();
      expect(c.hiddenScenes, isEmpty);
      expect(c.hiddenTracks, isEmpty);
    });

    test('remembered focus setup is stored', () async {
      final c = SettingsController();
      await c.rememberFocusSetup(50, 10);
      final again = SettingsController();
      expect(again.focusMinutes, 50);
      expect(again.focusBreakMinutes, 10);
    });
  });
}
