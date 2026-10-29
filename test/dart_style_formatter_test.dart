import 'package:dartlab/services/dart_style_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = DartStyleFormatter();

  group('DartStyleFormatter', () {
    test('lays out messy code', () async {
      final result = await formatter.format("void main(){print( 'hi' );}\n");

      expect(result.error, isNull);
      expect(result.text, "void main() {\n  print('hi');\n}\n");
    });

    test('code that is already formatted is left as it is', () async {
      final result = await formatter.format("void main() {\n  print('hi');\n}\n");

      expect(result.text, isNull);
      expect(result.error, isNull);
    });

    test('Bengali text inside strings and comments is untouched', () async {
      final result = await formatter.format(
        "void main(){\n// শুভ সকাল\nprint('শুভ সকাল');}\n",
      );

      expect(result.text, contains('// শুভ সকাল'));
      expect(result.text, contains("print('শুভ সকাল');"));
    });

    test('a syntax error is reported with its line, the code is not changed', () async {
      final result = await formatter.format("void main() {\n  print('hi')\n}\n");

      expect(result.text, isNull);
      expect(result.error, startsWith('line '));
    });

    test('the cursor stays on the same code', () async {
      const source = "void main(){print( 'hi' );}\n";
      final cursor = source.indexOf("'hi'");

      final result = await formatter.format(source, cursorOffset: cursor);

      final formatted = result.text!;
      final newCursor = result.cursor!;
      expect(formatted.substring(newCursor), startsWith("'hi'"));
    });

    test('long lines are wrapped at the page width', () async {
      final narrow = DartStyleFormatter(pageWidth: 30);
      const source = "void main() { print('a long message that does not fit'); }\n";

      final result = await narrow.format(source);

      expect(result.text!.split('\n').length, greaterThan(3));
    });

    test('the end of the file is a single line break', () async {
      final result = await formatter.format('void main() {}');

      expect(result.text, endsWith('}\n'));
    });
  });
}
