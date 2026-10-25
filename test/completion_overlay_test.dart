import 'package:dartlab/utils/themes.dart';
import 'package:dartlab/widgets/code_editor_controller.dart';
import 'package:dartlab/widgets/completion_model.dart';
import 'package:dartlab/widgets/completion_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CodeEditorController editorWith(String text) {
  final controller = CodeEditorController(scheme: EditorColorScheme.dark);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  return controller;
}

Future<void> show(WidgetTester tester, CompletionModel model) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: CompletionOverlay(model: model))),
    ),
  );
}

void main() {
  group('CompletionOverlay', () {
    testWidgets('shows nothing when there is no suggestion', (tester) async {
      await show(tester, CompletionModel(editorWith('print(x); ')));

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('shows the suggestions of the word at the cursor', (tester) async {
      await show(tester, CompletionModel(editorWith('pri')));

      expect(find.text('print'), findsOneWidget);
    });

    testWidgets('tapping a suggestion inserts it, cursor in the quotes', (tester) async {
      final controller = editorWith('pri');
      await show(tester, CompletionModel(controller));

      await tester.tap(find.text('print'));
      await tester.pump();

      expect(controller.text, "print('');");
      expect(controller.selection.baseOffset, 7);
    });

    testWidgets('the bar is tall enough for a finger (44)', (tester) async {
      await show(tester, CompletionModel(editorWith('pri')));

      final bar = tester.getSize(find.byType(ListView).first);

      expect(bar.height, greaterThanOrEqualTo(44));
    });

    testWidgets('the suggestions go away once the word is complete', (tester) async {
      final controller = editorWith('pri');
      await show(tester, CompletionModel(controller));

      controller.value = const TextEditingValue(
        text: 'pri ',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();

      expect(find.text('print'), findsNothing);
    });

    testWidgets('each suggestion can be read by a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, CompletionModel(editorWith('pri')));

      expect(find.bySemanticsLabel('Insert print'), findsOneWidget);
      handle.dispose();
    });
  });
}
