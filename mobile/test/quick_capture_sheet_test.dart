import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:khuta/features/todos/pages/todos_page.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

import 'support/app_harness.dart';

const _headline =
    'الخميس عندي اجتماع الساعة 5 العصر، وبدي أشتري هدية، وذكرني أتصل بأمي';
const _threePlain = 'اشتري خبز، اتصل بأمي، كلم الصيدلية';

TodosController _todos(WidgetTester tester) =>
    tester.element(find.byType(TodosPage)).read<TodosController>();

Future<void> _open(WidgetTester tester, {Locale? locale, String? tooltip}) async {
  await pumpScreen(tester, const TodosPage(), locale: locale);
  await tester.tap(find.byTooltip(tooltip ?? 'Quick capture'));
  await tester.pumpAndSettle();
}

Future<void> _find(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('capture_input')), text);
  await tester.pump();
  await tester.tap(find.byKey(const Key('capture_find')));
  await tester.pumpAndSettle();
}

// Writes need real time; what runs after each one runs on the test clock, so
// alternate between them, then let the widget-sync debounce timer (0.7 s) fire.
Future<void> _settleWrites(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

VoidCallback? _saveAction(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('capture_save'))).onPressed;

void main() {
  useEmptyStore();

  testWidgets('the Tasks bar opens quick capture with an empty input',
      (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('capture_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture_row_0')), findsNothing);
  });

  testWidgets('the headline sentence: needs a time, then saves three to-dos',
      (tester) async {
    await _open(tester);
    await _find(tester, _headline);

    expect(find.byKey(const ValueKey('capture_row_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture_row_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture_row_2')), findsOneWidget);
    expect(find.text('Needs a time'), findsOneWidget);
    expect(_saveAction(tester), isNull);

    await tester.tap(find.text('Not a reminder'));
    await tester.pumpAndSettle();
    expect(_saveAction(tester), isNotNull);
    expect(find.text('Save 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_save')));
    await tester.pump();
    await _settleWrites(tester);

    expect(_todos(tester).all, hasLength(3));
    expect(find.byKey(const Key('capture_input')), findsNothing);
  });

  testWidgets('nothing is stored before Save', (tester) async {
    await _open(tester);
    await _find(tester, _threePlain);
    expect(find.byKey(const ValueKey('capture_row_2')), findsOneWidget);
    expect(_todos(tester).all, isEmpty);
  });

  testWidgets('an unchecked row and a removed row are not saved',
      (tester) async {
    await _open(tester);
    await _find(tester, _threePlain);

    await tester.tap(find.byKey(const ValueKey('capture_check_0')));
    await tester.tap(find.byKey(const ValueKey('capture_remove_2')));
    await tester.pumpAndSettle();
    expect(find.text('Save 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_save')));
    await tester.pump();
    await _settleWrites(tester);

    expect(_todos(tester).all.map((t) => t.text), ['اتصل بأمي']);
  });

  testWidgets('input with nothing to do says so and cannot be saved',
      (tester) async {
    await _open(tester);
    await _find(tester, '!!!');
    expect(find.byKey(const Key('capture_nothing')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture_row_0')), findsNothing);
    expect(_saveAction(tester), isNull);
  });

  testWidgets('tapping Save twice quickly stores each item once',
      (tester) async {
    await _open(tester);
    await _find(tester, 'اشتري خبز، اتصل بأمي');
    final save = find.byKey(const Key('capture_save'));
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    await _settleWrites(tester);
    expect(_todos(tester).all, hasLength(2));
  });

  testWidgets('in Arabic the sheet is right-to-left with Western digits',
      (tester) async {
    await _open(tester, locale: const Locale('ar'), tooltip: 'إدخال سريع');
    expect(
      Directionality.of(tester.element(find.byKey(const Key('capture_input')))),
      TextDirection.rtl,
    );
    await _find(tester, _headline);
    expect(find.text('يحتاج وقتاً'), findsOneWidget);
    final arabicIndic = RegExp('[٠-٩۰-۹]');
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.data ?? '', isNot(matches(arabicIndic)));
    }
  });

  testWidgets('review: an importance word shows as a priority and can be cleared',
      (tester) async {
    await _open(tester);
    await _find(tester, 'ضروري اشتري خبز');
    expect(find.text('High'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('capture_priority_clear_0')));
    await tester.pumpAndSettle();
    expect(find.text('High'), findsNothing);
    await tester.tap(find.byKey(const Key('capture_save')));
    await tester.pump();
    await _settleWrites(tester);
    expect(_todos(tester).all.single.priority.name, 'none');
  });

  testWidgets('review: a negated importance word shows as low', (tester) async {
    await _open(tester);
    await _find(tester, 'مش ضروري اشتري خبز');
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('High'), findsNothing);
  });

  testWidgets('review: a note can be turned into a to-do before saving',
      (tester) async {
    await _open(tester);
    await _find(tester, 'ملاحظة: فكرة تطبيق');
    expect(find.text('Note'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('capture_kind_0')));
    await tester.pumpAndSettle();
    expect(find.text('Note'), findsNothing);
    await tester.tap(find.byKey(const Key('capture_save')));
    await tester.pump();
    await _settleWrites(tester);
    expect(_todos(tester).all.single.text, 'فكرة تطبيق');
  });

  testWidgets('review: on a small screen with the keyboard up Save stays visible',
      (tester) async {
    await pumpScreen(tester, const TodosPage());
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    // The Tasks page behind the sheet overflows by itself at this height; that
    // is not what is under test.
    tester.takeException();
    await tester.tap(find.byTooltip('Quick capture'));
    await tester.pumpAndSettle();
    await _find(tester, _headline);
    expect(tester.takeException(), isNull);
    final save = tester.getRect(find.byKey(const Key('capture_save')));
    expect(save.bottom, lessThanOrEqualTo(640 - 300 + 1),
        reason: 'Save must sit above the keyboard');
  });

  testWidgets('review: every tap target in the sheet has a label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    await _find(tester, _headline);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
