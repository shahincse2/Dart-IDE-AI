import 'package:dartlab/utils/hidden_text.dart';
import 'package:dartlab/utils/themes.dart';
import 'package:dartlab/widgets/code_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const block = 'void main() {\n  a();\n  b();\n}\n';

CodeEditorController make([String text = '']) =>
    CodeEditorController(scheme: EditorColorScheme.dark, text: text);

TextEditingValue at(String text, int cursor) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );

List<int> hidden(CodeEditorController c) => [
      for (final r in c.hiddenLineRanges) ...[r.first, r.last]
    ];

void main() {
  group('typing', () {
    test('an opener gets its closer', () {
      final c = make()..value = at('f', 1);

      c.value = at('f(', 2);

      expect(c.text, 'f()');
      expect(c.selection.baseOffset, 2);
    });

    test('Enter after a bracket indents the next line', () {
      final c = make()..value = at('if (x) {', 8);

      c.value = at('if (x) {\n', 9);

      expect(c.text, 'if (x) {\n  ');
    });

    test('the indent size can be changed', () {
      final c = make()
        ..indentSize = 4
        ..value = at('f(', 2);

      c.value = at('f(\n', 3);

      expect(c.text, 'f(\n    ');
    });
  });

  group('folding', () {
    test('foldAll hides the lines inside the braces', () {
      final c = make(block)..foldAll();

      expect(c.hasFolds, isTrue);
      expect(hidden(c), [1, 2]);
      expect(c.foldedStartLines, [0]);
      expect(c.hiddenSignature, '1-2');
    });

    test('toggleFold folds and unfolds', () {
      final c = make(block);

      c.toggleFold(0);
      expect(c.isFolded(0), isTrue);
      c.toggleFold(0);
      expect(c.isFolded(0), isFalse);
    });

    test('toggleFold on a line with nothing to fold does nothing', () {
      final c = make(block);
      var heard = 0;
      c.addListener(() => heard++);

      c.toggleFold(2);

      expect(heard, 0);
    });

    test('unfoldAll opens everything and tells the listeners', () {
      final c = make(block)..foldAll();
      var heard = 0;
      c.addListener(() => heard++);

      c.unfoldAll();

      expect(c.hasFolds, isFalse);
      expect(heard, 1);
    });

    test('folding moves a cursor that was inside to the line above', () {
      final c = make(block)..value = at(block, 17); // inside "  a();"

      c.foldAll();

      expect(c.selection.baseOffset, 13); // end of "void main() {"
    });

    test('moving the cursor into folded text unfolds it', () {
      final c = make(block)
        ..value = at(block, 0)
        ..foldAll();

      c.selection = const TextSelection.collapsed(offset: 20);

      expect(c.hasFolds, isFalse);
    });

    test('a line added above moves the fold down', () {
      final c = make('int x;\n$block')
        ..value = at('int x;\n$block', 0)
        ..foldAll();

      c.value = at('import "a";\nint x;\n$block', 0);

      expect(c.foldedStartLines, [2]);
    });

    test('an edit inside the folded lines unfolds it', () {
      final c = make(block)
        ..value = at(block, 0)
        ..foldAll();

      c.value = at(block.replaceFirst('a();', 'aa();'), 0);

      expect(c.hasFolds, isFalse);
    });

    test('an error inside a fold opens it, and the marker stays', () {
      final c = make(block)..foldAll();

      c.setErrorLine(2); // 1-indexed: "  a();"

      expect(c.hasFolds, isFalse);
      expect(c.errorLine, 2);
    });

    test('foldRegions is the same list until the text changes', () {
      final c = make(block);

      expect(identical(c.foldRegions, c.foldRegions), isTrue);
    });
  });

  group('error line', () {
    test('is cleared by an edit', () {
      final c = make('a')..value = at('a', 1);
      c.setErrorLine(1);

      c.value = at('ab', 2);

      expect(c.errorLine, isNull);
    });

    test('is kept when only the cursor moves', () {
      final c = make('ab')..value = at('ab', 2);
      c.setErrorLine(1);

      c.selection = const TextSelection.collapsed(offset: 1);

      expect(c.errorLine, 1);
    });
  });

  group('search highlights', () {
    test('tell the listeners', () {
      final c = make('abcabc');
      var heard = 0;
      c.addListener(() => heard++);

      c.setSearchHighlights([0, 3], 3);
      c.setActiveSearchMatch(1);

      expect(heard, 2);
      expect(c.searchHighlights.starts, [0, 3]);
      expect(c.searchHighlights.active, 1);
    });

    test('no matches means no active match', () {
      final c = make('abc')
        ..setSearchHighlights([0], 1)
        ..setActiveSearchMatch(0);

      c.setSearchHighlights([]);

      expect(c.searchHighlights.active, -1);
    });
  });

  group('drawing', () {
    testWidgets('the drawn text is the text, folded or not', (tester) async {
      final c = make(block);
      late BuildContext context;
      await tester.pumpWidget(Builder(builder: (ctx) {
        context = ctx;
        return const SizedBox();
      }));

      final plain = c.buildTextSpan(
          context: context, style: const TextStyle(), withComposing: false);
      expect(plain.toPlainText(), block);

      c.foldAll();
      final folded = c.buildTextSpan(
          context: context, style: const TextStyle(), withComposing: false);
      final pieces = folded.children!.cast<TextSpan>();
      final hiddenPart = pieces
          .where((p) => p.style?.fontSize == kHiddenFontSize)
          .map((p) => p.text)
          .join();
      final shownPart = pieces
          .where((p) => p.style?.fontSize != kHiddenFontSize)
          .map((p) => p.text)
          .join();

      expect(folded.toPlainText().length, block.length); // nothing is removed
      expect(hiddenPart, contains('a();'));
      expect(shownPart, isNot(contains('a();')));
      expect(shownPart, contains('void main() {'));
    });
  });
}
