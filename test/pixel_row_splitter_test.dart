import 'package:dartlab/widgets/console/pixel_row_splitter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// flutter_test draws every glyph as a 1em square (the "Ahem" font), so with
// fontSize 10 each character, spaces included, is exactly 10 px wide.
const style = TextStyle(fontSize: 10);

void main() {
  group('splitByPixels', () {
    test('text that fits stays on one row', () {
      expect(splitByPixels('hello', style, 200), ['hello']);
      expect(splitByPixels('', style, 200), ['']);
    });

    test('breaks at spaces and keeps words whole', () {
      expect(splitByPixels('aaaa bbbb cccc', style, 55), ['aaaa', 'bbbb', 'cccc']);
    });

    test('cuts a word that is wider than a row', () {
      expect(splitByPixels('abcdefghij', style, 45), ['abcd', 'efgh', 'ij']);
    });
  });

  group('isPlainAscii', () {
    test('is true only for plain ASCII', () {
      expect(isPlainAscii('hello world'), isTrue);
      expect(isPlainAscii('héllo'), isFalse);
      expect(isPlainAscii('বাংলা'), isFalse);
      expect(isPlainAscii('a\tb'), isFalse);
    });
  });
}
