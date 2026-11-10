import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/app/theme/app_theme.dart';
import 'package:khuta/features/settings/pages/about_page.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';
import 'package:khuta/features/settings/widgets/legal_notices.dart';
import 'package:khuta/l10n/app_localizations.dart';

import 'support/app_harness.dart';

const _attribution = 'Based on Streak by InlitX';

void main() {
  useEmptyStore();

  testWidgets('the attribution renders in every shipped locale', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: LegalNotices()),
        ),
      );
      await tester.pumpAndSettle();

      final strings = lookupAppLocalizations(locale);
      expect(
        find.text(strings.legal_attribution),
        findsOneWidget,
        reason: 'attribution missing for $locale',
      );
      expect(strings.legal_attribution, contains('InlitX'));
      expect(strings.legal_attribution, contains('Streak'));
      expect(find.text(strings.legal_licenses), findsOneWidget);
    }
  });

  testWidgets('English uses the exact required notice', (tester) async {
    expect(
      lookupAppLocalizations(const Locale('en')).legal_attribution,
      _attribution,
    );
  });

  for (final style in const {
    0: 'classic',
    1: 'minimal',
    2: 'express',
  }.entries) {
    testWidgets(
      '${style.value}: settings link to About, which shows the notice and the licenses',
      (tester) async {
        await pumpScreen(
          tester,
          const SettingsPage(),
          settings: {'appStyle': style.key},
          settle: false,
        );
        await tester.pump(const Duration(seconds: 1));
        await scrollToEnd(tester);

        // The settings screen itself no longer carries the notice.
        expect(find.text(_attribution), findsNothing);
        await tester.tap(find.text('About this app'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(AboutPage), findsOneWidget);
        expect(find.text('Ayoub Droubi'), findsOneWidget);
        expect(find.text(_attribution), findsOneWidget);
        await tester.tap(find.text('Open source licenses'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(LicensePage), findsOneWidget);
      },
    );
  }

  for (final locale in const ['en', 'ar', 'de', 'he']) {
    testWidgets('About shows the owner above the attribution in $locale',
        (tester) async {
      await pumpScreen(
        tester,
        const AboutPage(),
        locale: Locale(locale),
        textScale: 2,
        settle: false,
      );
      tester.view.physicalSize = const Size(1080, 9000);
      await tester.pump(const Duration(seconds: 1));
      final strings = lookupAppLocalizations(Locale(locale));
      final owner = tester.getTopLeft(find.text('Ayoub Droubi')).dy;
      final notice = tester.getTopLeft(find.text(strings.legal_attribution)).dy;
      expect(notice, greaterThan(owner));
      expect(tester.takeException(), isNull);
    });
  }
}
