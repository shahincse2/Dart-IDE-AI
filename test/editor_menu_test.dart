import 'package:dartlab/screens/editor/editor_actions.dart';
import 'package:dartlab/screens/editor/editor_menu.dart';
import 'package:dartlab/utils/feature_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EditorActions actionsLogging(List<String> log, {bool withFile = true}) {
  VoidCallback? ifFile(String name) => withFile ? () => log.add(name) : null;
  return EditorActions(
    run: ifFile('run'),
    save: ifFile('save'),
    find: ifFile('find'),
    goToLine: ifFile('goto'),
    format: ifFile('format'),
    foldAll: ifFile('foldAll'),
    unfoldAll: ifFile('unfoldAll'),
    export: ifFile('export'),
    importFile: () => log.add('import'),
    shareCode: ifFile('share'),
    printCode: ifFile('print'),
    sharePdf: ifFile('pdf'),
    previewUi: ifFile('preview'),
    inspect: () => log.add('inspect'),
    git: ifFile('git'),
    settings: () => log.add('settings'),
    toggleWordWrap: () => log.add('wrap'),
    fontSize: () => log.add('font'),
  );
}

Future<void> openMenu(
  WidgetTester tester,
  EditorActions actions, {
  bool useSidebar = false,
  bool wordWrap = true,
}) async {
  // Tall enough that every item can be reached.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            EditorMenu(
                actions: actions, useSidebar: useSidebar, wordWrap: wordWrap),
          ],
        ),
      ),
    ),
  );
  await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
  await tester.pumpAndSettle();
}

void main() {
  group('EditorMenu', () {
    testWidgets('lists every item', (tester) async {
      await openMenu(tester, actionsLogging([]));

      for (final title in [
        'Format code',
        'Go to line',
        'Fold all',
        'Unfold all',
        'Font size',
        'Word wrap',
        'Export file',
        'Import file',
        'Share code',
        'Print',
        'Share as PDF',
        'Preview UI',
        'Inspect variables',
        'Settings',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('the Git item shows only when Git is switched on',
        (tester) async {
      await openMenu(tester, actionsLogging([]));

      expect(
        find.text('Push to GitHub / GitLab'),
        kGitEnabled ? findsOneWidget : findsNothing,
      );
    });

    testWidgets('choosing an item runs its action', (tester) async {
      final log = <String>[];
      await openMenu(tester, actionsLogging(log));

      await tester.tap(find.text('Go to line'));
      await tester.pumpAndSettle();

      expect(log, ['goto']);
    });

    testWidgets('Import and Settings work even with no file open',
        (tester) async {
      final log = <String>[];
      await openMenu(tester, actionsLogging(log, withFile: false));

      await tester.tap(find.text('Import file'));
      await tester.pumpAndSettle();

      expect(log, ['import']);
    });

    testWidgets('with no file open the file items do nothing', (tester) async {
      final log = <String>[];
      await openMenu(tester, actionsLogging(log, withFile: false));

      await tester.tap(find.text('Format code'));
      await tester.pumpAndSettle();

      expect(log, isEmpty);
      expect(find.text('Go to line'), findsOneWidget); // the menu is still open
    });

    testWidgets('the shortcut is not shown on a narrow screen', (tester) async {
      await openMenu(tester, actionsLogging([]), useSidebar: false);

      expect(find.text('Ctrl+Alt+L'), findsNothing);
    });

    testWidgets('the shortcut is shown on a wide screen', (tester) async {
      await openMenu(tester, actionsLogging([]), useSidebar: true);

      expect(find.text('Ctrl+Alt+L'), findsOneWidget);
    });

    testWidgets('Word wrap is ticked when it is on', (tester) async {
      await openMenu(tester, actionsLogging([]), wordWrap: true);

      final item = tester.widget<CheckedPopupMenuItem<VoidCallback>>(
        find.byType(CheckedPopupMenuItem<VoidCallback>),
      );

      expect(item.checked, isTrue);
    });

    testWidgets('choosing Word wrap toggles it', (tester) async {
      final log = <String>[];
      await openMenu(tester, actionsLogging(log));

      await tester.tap(find.byType(CheckedPopupMenuItem<VoidCallback>));
      await tester.pumpAndSettle();

      expect(log, ['wrap']);
    });
  });
}
