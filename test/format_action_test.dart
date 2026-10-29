import 'package:dartlab/services/code_formatter.dart';
import 'package:dartlab/utils/themes.dart';
import 'package:dartlab/widgets/code_editor_controller.dart';
import 'package:dartlab/widgets/format_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A formatter that answers with a prepared result (and can wait first).
class _FakeFormatter implements CodeFormatter {
  _FakeFormatter(this.result, {this.beforeAnswering});

  final FormatResult result;
  final void Function()? beforeAnswering;
  String? receivedSource;
  int? receivedCursor;

  @override
  Future<FormatResult> format(String source, {int cursorOffset = 0}) async {
    receivedSource = source;
    receivedCursor = cursorOffset;
    beforeAnswering?.call();
    return result;
  }
}

CodeEditorController editorWith(String text, {int? cursor}) {
  final controller = CodeEditorController(scheme: EditorColorScheme.dark);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );
  return controller;
}

Future<void> runFormat(
  WidgetTester tester,
  CodeEditorController controller,
  CodeFormatter formatter,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => formatWithMessage(context, controller, formatter: formatter),
            child: const Text('format'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('format'));
  await tester.pump();
  await tester.pump();
}

Future<void> letMessageGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pump();
}

void main() {
  group('formatWithMessage', () {
    testWidgets('puts the formatted text in and moves the cursor', (tester) async {
      final controller = editorWith('a=1;', cursor: 2);
      final formatter = _FakeFormatter(const FormatResult.formatted('a = 1;\n', 4));

      await runFormat(tester, controller, formatter);

      expect(controller.text, 'a = 1;\n');
      expect(controller.selection.baseOffset, 4);
      expect(find.text('Formatted'), findsOneWidget);
      await letMessageGo(tester);
    });

    testWidgets('hands the formatter the text and where the cursor is', (tester) async {
      final controller = editorWith('a=1;', cursor: 2);
      final formatter = _FakeFormatter(const FormatResult.unchanged());

      await runFormat(tester, controller, formatter);

      expect(formatter.receivedSource, 'a=1;');
      expect(formatter.receivedCursor, 2);
      await letMessageGo(tester);
    });

    testWidgets('already formatted: nothing changes, and it says so', (tester) async {
      final controller = editorWith('a = 1;\n');

      await runFormat(tester, controller, _FakeFormatter(const FormatResult.unchanged()));

      expect(controller.text, 'a = 1;\n');
      expect(find.text('Already formatted'), findsOneWidget);
      await letMessageGo(tester);
    });

    testWidgets('a syntax error leaves the text alone and says what is wrong', (tester) async {
      final controller = editorWith("print('hi')");

      await runFormat(
        tester,
        controller,
        _FakeFormatter(const FormatResult.failed("line 1: Expected ';' after this.")),
      );

      expect(controller.text, "print('hi')");
      expect(find.text("Could not format: line 1: Expected ';' after this."), findsOneWidget);
      await letMessageGo(tester);
    });

    testWidgets('text typed while formatting is not overwritten', (tester) async {
      final controller = editorWith('a=1;');
      final formatter = _FakeFormatter(
        const FormatResult.formatted('a = 1;\n', 4),
        beforeAnswering: () => controller.value = const TextEditingValue(
          text: 'a=1;b',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      await runFormat(tester, controller, formatter);

      expect(controller.text, 'a=1;b');
      expect(find.textContaining('changed while formatting'), findsOneWidget);
      await letMessageGo(tester);
    });

    testWidgets('a cursor beyond the new text is kept inside it', (tester) async {
      final controller = editorWith('abc');

      await runFormat(
        tester,
        controller,
        _FakeFormatter(const FormatResult.formatted('ab\n', 99)),
      );

      expect(controller.selection.baseOffset, 3);
      await letMessageGo(tester);
    });
  });
}
