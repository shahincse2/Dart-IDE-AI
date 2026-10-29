import 'package:dartlab/utils/dart_syntax_highlighter.dart';
import 'package:dartlab/utils/fold_regions.dart';
import 'package:dartlab/utils/hidden_text.dart';
import 'package:dartlab/utils/highlight_spans.dart';
import 'package:dartlab/utils/string_escapes.dart';
import 'package:dartlab/utils/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const source = "void main() {\n  print('hi\\n');\n}\n";

TextSpan build({
  int? open,
  int? close,
  SearchHighlights search = const SearchHighlights(),
  List<CharRange> hidden = const [],
}) {
  return buildHighlightedSpan(
    source: source,
    style: const TextStyle(),
    scheme: EditorColorScheme.dark,
    tokens: tokenizeDart(source),
    escapes: EscapeRanges.empty,
    openBracket: open,
    closeBracket: close,
    search: search,
    hidden: hidden,
  );
}

List<TextSpan> pieces(TextSpan span) => span.children!.cast<TextSpan>();

void main() {
  group('buildHighlightedSpan', () {
    test('draws exactly the source text', () {
      expect(build().toPlainText(), source);
    });

    test('colours keywords differently from plain text', () {
      final colours = pieces(build()).map((p) => p.style?.color).toSet();

      expect(colours.length, greaterThan(1));
    });

    test('a matching bracket pair is drawn bold', () {
      final bold = pieces(build(open: 9, close: 10))
          .where((p) => p.style?.fontWeight == FontWeight.w700)
          .map((p) => p.text);

      expect(bold, ['(', ')']);
    });

    test('a search match gets a background', () {
      final marked = pieces(build(
              search:
                  const SearchHighlights(starts: [5], length: 4, active: 0)))
          .where((p) => p.style?.backgroundColor != null)
          .map((p) => p.text)
          .join();

      expect(marked, 'main');
    });

    test('the active match is stronger than the others', () {
      final span = build(
          search:
              const SearchHighlights(starts: [5, 20], length: 4, active: 1));
      final backgrounds = pieces(span)
          .where((p) => p.style?.backgroundColor != null)
          .map((p) => p.style!.backgroundColor)
          .toSet();

      expect(backgrounds.length, 2);
    });

    test('a hidden range is drawn invisible and keeps its length', () {
      final span = build(hidden: [CharRange(14, 31)]);
      final hiddenPart = pieces(span)
          .where((p) => p.style?.fontSize == kHiddenFontSize)
          .map((p) => p.text)
          .join();

      expect(span.toPlainText().length, source.length);
      expect(hiddenPart.length, 17);
    });

    test('the last piece of a hidden range keeps a real line break', () {
      final span = build(hidden: [CharRange(14, 31)]);

      expect(span.toPlainText().substring(14, 31).endsWith('\n'), isTrue);
    });
  });
}
