import 'package:dart_ide/utils/themes.dart';
import 'package:dart_ide/widgets/code_editor/editor_surface.dart';
import 'package:dart_ide/widgets/code_editor/line_layout.dart';
import 'package:dart_ide/widgets/code_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts how often the text field asks for its coloured text, which it does
/// every time it is rebuilt.
class _CountingController extends CodeEditorController {
  _CountingController(String text)
      : super(scheme: EditorColorScheme.dark, text: text);

  int asked = 0;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    asked++;
    return super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
  }
}

void main() {
  testWidgets('scrolling does not rebuild the text field', (tester) async {
    final controller = _CountingController(
      List.generate(300, (i) => 'int line$i = $i;').join('\n'),
    );
    final scroll = ScrollController();
    final focus = FocusNode();
    addTearDown(() {
      scroll.dispose();
      focus.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: EditorSurface(
              controller: controller,
              layout: LineLayout(),
              scrollController: scroll,
              focusNode: focus,
              undoController: null,
              fontSize: 14,
              wordWrap: false,
              regionByStart: const {},
            ),
          ),
        ),
      ),
    );
    final askedBefore = controller.asked;

    for (var offset = 40.0; offset <= 400; offset += 40) {
      scroll.jumpTo(offset);
      await tester.pump();
    }

    expect(scroll.offset, 400);
    expect(controller.asked, askedBefore);
  });

  testWidgets('the line numbers follow the scroll', (tester) async {
    final controller = _CountingController(
      List.generate(300, (i) => 'int line$i = $i;').join('\n'),
    );
    final scroll = ScrollController();
    final focus = FocusNode();
    addTearDown(() {
      scroll.dispose();
      focus.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: EditorSurface(
              controller: controller,
              layout: LineLayout(),
              scrollController: scroll,
              focusNode: focus,
              undoController: null,
              fontSize: 14,
              wordWrap: false,
              regionByStart: const {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('250'), findsNothing);

    scroll.jumpTo(250 * 21.0);
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.text('250'), findsOneWidget);
  });

  testWidgets('switching word wrap on and off does not break the editor', (tester) async {
    final controller = _CountingController(
      List.generate(120, (i) => 'int line$i = $i;').join('\n'),
    );
    final scroll = ScrollController();
    final focus = FocusNode();
    addTearDown(() {
      scroll.dispose();
      focus.dispose();
    });

    Widget editor({required bool wordWrap}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: EditorSurface(
                controller: controller,
                layout: LineLayout(),
                scrollController: scroll,
                focusNode: focus,
                undoController: null,
                fontSize: 14,
                wordWrap: wordWrap,
                regionByStart: const {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(editor(wordWrap: false));
    await tester.pumpWidget(editor(wordWrap: true));
    await tester.pumpWidget(editor(wordWrap: false));

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}
