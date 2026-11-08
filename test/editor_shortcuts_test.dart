import 'package:dartlab/screens/editor/editor_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> pumpShortcuts(WidgetTester tester) async {
  final log = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: CallbackShortcuts(
        bindings: editorShortcuts(
          onSave: () => log.add('save'),
          onRunOrStop: () => log.add('run'),
          onOpenFind: ({required expandReplace}) =>
              log.add(expandReplace ? 'replace' : 'find'),
          onGoToLine: () => log.add('goto'),
          onFormat: () => log.add('format'),
        ),
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ),
  );
  return log;
}

Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool ctrl = false,
  bool alt = false,
}) async {
  if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

void main() {
  group('editorShortcuts', () {
    testWidgets('Ctrl+S saves', (tester) async {
      final log = await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.keyS, ctrl: true);

      expect(log, ['save']);
    });

    testWidgets('Ctrl+Enter runs or stops', (tester) async {
      final log = await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.enter, ctrl: true);

      expect(log, ['run']);
    });

    testWidgets('Ctrl+F opens find, Ctrl+H opens find and replace', (tester) async {
      final log = await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.keyF, ctrl: true);
      await press(tester, LogicalKeyboardKey.keyH, ctrl: true);

      expect(log, ['find', 'replace']);
    });

    testWidgets('Ctrl+G goes to a line', (tester) async {
      final log = await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.keyG, ctrl: true);

      expect(log, ['goto']);
    });

    testWidgets('Ctrl+Alt+L formats', (tester) async {
      final log = await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.keyL, ctrl: true, alt: true);

      expect(log, ['format']);
    });

    testWidgets('Ctrl+L alone does not format', (tester) async {
      final log = await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.keyL, ctrl: true);

      expect(log, isEmpty);
    });

    testWidgets('a plain S does nothing, and Ctrl+Z is left to the text field', (tester) async {
      final log = await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.keyS);
      await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);

      expect(log, isEmpty);
    });
  });
}
