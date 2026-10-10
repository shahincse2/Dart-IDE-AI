import 'package:dartlab/utils/string_escapes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findStringEscapes', () {
    test('finds \\n inside a string and nothing around it', () {
      const text = r"print('a\nb');";
      // The string literal is 'a\nb' = offsets 6..12.
      final escapes = findStringEscapes(text, [6, 12]);

      expect(escapes.covers(8, 10), isTrue);
      expect(escapes.covers(8, 9), isTrue);
      expect(escapes.covers(7, 8), isFalse);
      expect(escapes.covers(10, 11), isFalse);
    });

    test('handles \\u, \\u{...} and \\x escapes', () {
      const text = r"'\u00e9 \u{1F600} \x41'";
      final escapes = findStringEscapes(text, [0, text.length]);

      expect(escapes.boundaries.toList(), [1, 7, 8, 17, 18, 22]);
    });

    test('raw strings have no escapes', () {
      const text = r"r'\n'";
      expect(findStringEscapes(text, [0, 5]).boundaries, isEmpty);
      expect(findStringEscapes(text, [1, 5]).boundaries, isEmpty);
    });

    test('escape-looking text outside strings is ignored', () {
      const text = r'print(a\n)';
      expect(findStringEscapes(text, const []).boundaries, isEmpty);
      expect(EscapeRanges.empty.covers(0, 1), isFalse);
    });

    test('overlapping string ranges do not report an escape twice', () {
      const text = r"'a\nb'";
      final escapes = findStringEscapes(text, [0, 6, 0, 6]);

      expect(escapes.boundaries.toList(), [2, 4]);
    });
  });
}
