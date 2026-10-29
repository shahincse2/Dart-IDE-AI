import 'package:dartlab/utils/auto_pair.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue value(String text, int cursor) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );

void main() {
  group('applyAutoPair', () {
    test('an opener gets its closer, cursor between', () {
      final result = applyAutoPair(value('f', 1), value('f(', 2));

      expect(result.text, 'f()');
      expect(result.selection.baseOffset, 2);
    });

    test('every pair: ( { [ < and both quotes', () {
      const pairs = {'(': ')', '{': '}', '[': ']', '<': '>', "'": "'", '"': '"'};
      pairs.forEach((open, close) {
        final result = applyAutoPair(value('', 0), value(open, 1));

        expect(result.text, '$open$close', reason: open);
        expect(result.selection.baseOffset, 1, reason: open);
      });
    });

    test('typing the closer steps over the one already there', () {
      final result = applyAutoPair(value('f()', 2), value('f())', 3));

      expect(result.text, 'f()');
      expect(result.selection.baseOffset, 3);
    });

    test('typing a quote before the closing quote steps over it', () {
      final result = applyAutoPair(value("'a'", 2), value("'a''", 3));

      expect(result.text, "'a'");
      expect(result.selection.baseOffset, 3);
    });

    test('an opener typed over a selection wraps it', () {
      final result = applyAutoPair(
        const TextEditingValue(
          text: 'abc',
          selection: TextSelection(baseOffset: 0, extentOffset: 3),
        ),
        value('(', 1),
      );

      expect(result.text, '(abc)');
      expect(result.selection.baseOffset, 4);
    });

    test('a letter is not touched: the very same value comes back', () {
      final typed = value('ab', 2);

      expect(identical(applyAutoPair(value('a', 1), typed), typed), isTrue);
    });

    test('a closer with nothing to step over is just typed', () {
      final typed = value('a)', 2);

      expect(identical(applyAutoPair(value('a', 1), typed), typed), isTrue);
    });

    test('pasting more than one character is not touched', () {
      final pasted = value('f(a)', 4);

      expect(identical(applyAutoPair(value('f', 1), pasted), pasted), isTrue);
    });
  });
}
