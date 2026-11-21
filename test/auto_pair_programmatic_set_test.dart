import 'package:dart_ide/utils/auto_pair.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyAutoPair when the text is set from code, not typed', () {
    test('a one-character text over an empty editor does not crash', () {
      const newValue = TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 0),
      );

      final result = applyAutoPair(TextEditingValue.empty, newValue);

      expect(result.text, 'a');
    });

    test('a lone opener set that way is not paired', () {
      const newValue = TextEditingValue(
        text: '(',
        selection: TextSelection.collapsed(offset: 0),
      );

      expect(identical(applyAutoPair(TextEditingValue.empty, newValue), newValue), isTrue);
    });

    test('typing an opener at a real cursor still adds its closer', () {
      const before = TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
      const typed = TextEditingValue(
        text: '(',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = applyAutoPair(before, typed);

      expect(result.text, '()');
      expect(result.selection.baseOffset, 1);
    });
  });
}
