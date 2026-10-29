import 'package:dartlab/utils/fold_regions.dart';
import 'package:dartlab/utils/hidden_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hiddenText', () {
    test('has the same length as the real text', () {
      expect(hiddenText('ab\ncd\n', endsRange: true).length, 6);
      expect(hiddenText('ab\ncd', endsRange: false).length, 5);
    });

    test('the last line break of a range stays a real one', () {
      final shown = hiddenText('ab\ncd\n', endsRange: true);

      expect(shown.endsWith('\n'), isTrue);
      expect('\n'.allMatches(shown).length, 1);
    });

    test('the others become zero-width spaces', () {
      final shown = hiddenText('ab\ncd\n', endsRange: true);

      expect(shown.contains('\u200B'), isTrue);
    });

    test('a piece in the middle of a range has no real line break', () {
      expect(hiddenText('ab\ncd\n', endsRange: false).contains('\n'), isFalse);
    });
  });

  group('hiddenStyle', () {
    test('is tiny and transparent', () {
      final style =
          hiddenStyle(const TextStyle(fontSize: 14, color: Colors.red));

      expect(style.fontSize, kHiddenFontSize);
      expect(style.color, Colors.transparent);
    });
  });

  group('hiddenRangeCovering', () {
    final hidden = [CharRange(10, 20), CharRange(30, 40)];

    test('finds the range that holds a piece', () {
      expect(hiddenRangeCovering(hidden, 12, 18)?.start, 10);
      expect(hiddenRangeCovering(hidden, 30, 40)?.start, 30);
    });

    test('a piece that sticks out is not covered', () {
      expect(hiddenRangeCovering(hidden, 8, 12), isNull);
      expect(hiddenRangeCovering(hidden, 18, 32), isNull);
    });
  });

  group('buildComposingSpan', () {
    test('without folds it is the plain text', () {
      final span =
          buildComposingSpan(text: 'abc', style: null, hidden: const []);

      expect(span.toPlainText(), 'abc');
    });

    test('a folded part stays hidden and the length is kept', () {
      const text = 'a\nb\nc\nd\n';
      final span = buildComposingSpan(
          text: text, style: null, hidden: [CharRange(2, 6)]);

      final hiddenPart = span.children!
          .cast<TextSpan>()
          .where((p) => p.style?.fontSize == kHiddenFontSize)
          .map((p) => p.text)
          .join();
      expect(span.toPlainText().length, text.length);
      expect(hiddenPart.length, 4);
      expect(hiddenPart.endsWith('\n'), isTrue);
      expect('\n'.allMatches(hiddenPart).length, 1);
    });
  });
}
