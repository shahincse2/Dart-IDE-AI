import 'package:dartlab/utils/auto_indent.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue value(String text, int cursor) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );

void main() {
  group('applyAutoIndent', () {
    test('Enter keeps the indentation of the line above', () {
      final result = applyAutoIndent(
        value('  foo();', 8),
        value('  foo();\n', 9),
        indentSize: 2,
      );

      expect(result.text, '  foo();\n  ');
      expect(result.selection.baseOffset, 11);
    });

    test('Enter after an opening bracket adds one level', () {
      final result = applyAutoIndent(
        value('if (x) {', 8),
        value('if (x) {\n', 9),
        indentSize: 2,
      );

      expect(result.text, 'if (x) {\n  ');
    });

    test('the size of a level is the setting', () {
      final result = applyAutoIndent(
        value('f(', 2),
        value('f(\n', 3),
        indentSize: 4,
      );

      expect(result.text, 'f(\n    ');
    });

    test('Enter in the middle of a line moves the rest down, indented', () {
      final result = applyAutoIndent(
        value('{}', 1),
        value('{\n}', 2),
        indentSize: 2,
      );

      expect(result.text, '{\n  }');
      expect(result.selection.baseOffset, 4);
    });

    test('nothing to carry over: the very same value comes back', () {
      final typed = value('a\n', 2);

      expect(identical(applyAutoIndent(value('a', 1), typed, indentSize: 2), typed), isTrue);
    });

    test('ordinary typing is not touched', () {
      final typed = value('ab', 2);

      expect(identical(applyAutoIndent(value('a', 1), typed, indentSize: 2), typed), isTrue);
    });

    test('pasting text with line breaks is not touched', () {
      final pasted = value('a\nb\nc', 5);

      expect(identical(applyAutoIndent(value('a', 1), pasted, indentSize: 2), pasted), isTrue);
    });
  });
}
