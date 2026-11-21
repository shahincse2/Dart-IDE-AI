import 'package:dartlab/utils/themes.dart';
import 'package:dartlab/widgets/code_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 14);

CodeEditorController editorWith(String text, {int cursor = 0}) {
  final controller = CodeEditorController(scheme: EditorColorScheme.dark);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor),
  );
  return controller;
}

/// The coloured text the editor would draw (asked the way the text field asks).
Future<TextSpan Function({TextStyle? style})> spanOf(
  WidgetTester tester,
  CodeEditorController controller,
) async {
  late BuildContext context;
  await tester.pumpWidget(Builder(builder: (ctx) {
    context = ctx;
    return const SizedBox();
  }));
  return ({TextStyle? style = _style}) => controller.buildTextSpan(
        context: context,
        style: style,
        withComposing: false,
      );
}

void main() {
  group('the coloured text is remembered', () {
    testWidgets('asking again, as every rebuild does, gives the very same span', (tester) async {
      final controller = editorWith('void main() {}\n');
      final ask = await spanOf(tester, controller);

      expect(identical(ask(), ask()), isTrue);
    });

    testWidgets('a new text gives a new span', (tester) async {
      final controller = editorWith('int a = 1;');
      final ask = await spanOf(tester, controller);
      final before = ask();

      controller.value = const TextEditingValue(
        text: 'int a = 2;',
        selection: TextSelection.collapsed(offset: 0),
      );

      expect(identical(ask(), before), isFalse);
      expect(ask().toPlainText(), 'int a = 2;');
    });

    testWidgets('moving the cursor gives a new span (the bracket pair may change)', (tester) async {
      final controller = editorWith('f(x)', cursor: 1);
      final ask = await spanOf(tester, controller);
      final before = ask();

      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(identical(ask(), before), isFalse);
    });

    testWidgets('new search matches give a new span', (tester) async {
      final controller = editorWith('abc abc');
      final ask = await spanOf(tester, controller);
      final before = ask();

      controller.setSearchHighlights([0, 4], 3);

      expect(identical(ask(), before), isFalse);
    });

    testWidgets('a different style gives a new span', (tester) async {
      final controller = editorWith('int a;');
      final ask = await spanOf(tester, controller);
      final before = ask();

      expect(identical(ask(style: const TextStyle(fontSize: 20)), before), isFalse);
    });

    testWidgets('a new theme gives a new span', (tester) async {
      final controller = editorWith('int a;');
      final ask = await spanOf(tester, controller);
      final before = ask();

      controller.scheme = EditorColorScheme.light;
      await tester.pump();

      expect(identical(ask(), before), isFalse);
    });

    testWidgets('folding gives a new span', (tester) async {
      final controller = editorWith('void main() {\n  a();\n  b();\n}\n');
      final ask = await spanOf(tester, controller);
      final before = ask();

      controller.foldAll();

      expect(identical(ask(), before), isFalse);
    });
  });

  group('line count and cursor line', () {
    test('count the lines', () {
      expect(editorWith('').lineCount, 1);
      expect(editorWith('a').lineCount, 1);
      expect(editorWith('a\nb\n\nc').lineCount, 4);
      expect(editorWith('a\n').lineCount, 2);
    });

    test('say which line the cursor is on', () {
      expect(editorWith('a\nbb\n\nccc', cursor: 0).currentLine, 0);
      expect(editorWith('a\nbb\n\nccc', cursor: 3).currentLine, 1);
      expect(editorWith('a\nbb\n\nccc', cursor: 5).currentLine, 2);
      expect(editorWith('a\nbb\n\nccc', cursor: 9).currentLine, 3);
    });

    test('follow the text and the cursor', () {
      final controller = editorWith('a\nb', cursor: 3);
      expect(controller.currentLine, 1);

      controller.value = const TextEditingValue(
        text: 'a\nb\nc\nd',
        selection: TextSelection.collapsed(offset: 7),
      );

      expect(controller.lineCount, 4);
      expect(controller.currentLine, 3);
    });

    test('have no cursor line when there is no cursor', () {
      final controller = CodeEditorController(scheme: EditorColorScheme.dark, text: 'abc');

      expect(controller.currentLine, -1);
    });
  });
}
