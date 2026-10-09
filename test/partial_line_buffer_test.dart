import 'package:dartlab/services/console_io/partial_line_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PartialLineBuffer', () {
    late List<String> lines;
    late PartialLineBuffer buffer;

    setUp(() {
      lines = [];
      buffer = PartialLineBuffer(lines.add);
    });

    test('text without a newline waits until it is finished', () {
      buffer.write('Hel');
      buffer.write('lo');
      expect(lines, isEmpty);

      buffer.write(' there\nnext');
      expect(lines, ['Hello there']);

      buffer.flush();
      expect(lines, ['Hello there', 'next']);
    });

    test('a bare newline is an empty line', () {
      buffer.write('\n');
      expect(lines, ['']);
    });

    test('carriage returns are dropped, several lines in one write', () {
      buffer.write('a\r\nb\nc\n');
      expect(lines, ['a', 'b', 'c']);
    });

    test('flush with nothing pending emits nothing', () {
      buffer.flush();
      expect(lines, isEmpty);
    });

    test('a never-ending line is cut instead of growing forever', () {
      buffer.write('x' * 10000);
      expect(lines.length, 1);
    });
  });
}
