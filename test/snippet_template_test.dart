import 'package:dartlab/utils/snippet_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('expandSnippet', () {
    test('removes the markers and tells where they were', () {
      final snippet = expandSnippet("print('§');");

      expect(snippet.text, "print('');");
      expect(snippet.stops, [7]); // between the quotes
    });

    test('several stops come in text order', () {
      final snippet = expandSnippet('Map<§, §>');

      expect(snippet.text, 'Map<, >');
      expect(snippet.stops, [4, 6]);
    });

    test('a template without markers has no stops', () {
      final snippet = expandSnippet('void ');

      expect(snippet.text, 'void ');
      expect(snippet.stops, isEmpty);
    });

    test('later lines are lined up with the line the snippet goes into', () {
      final snippet = expandSnippet('if (§) {\n  §\n}', baseIndent: '  ');

      expect(snippet.text, 'if () {\n    \n  }');
      expect(snippet.stops, [4, 12]);
    });

    test('an indentation of 4 spaces per level is respected', () {
      final snippet = expandSnippet('if (§) {\n  §\n}', indentSize: 4);

      expect(snippet.text, 'if () {\n    \n}');
      expect(snippet.stops, [4, 12]);
    });

    test('a nested level gets one more indentation', () {
      final snippet = expandSnippet('a {\n  b {\n    §\n  }\n}', baseIndent: '    ');

      expect(snippet.text, 'a {\n      b {\n        \n      }\n    }');
    });

    test('the first line is not moved: it goes where the cursor is', () {
      final snippet = expandSnippet('x', baseIndent: '    ');

      expect(snippet.text, 'x');
    });
  });
}
