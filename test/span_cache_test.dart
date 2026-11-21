import 'package:dart_ide/utils/span_cache.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpanCache', () {
    test('the same inputs give the very same span, made once', () {
      final cache = SpanCache();
      var made = 0;
      TextSpan make() {
        made++;
        return TextSpan(text: 'span $made');
      }

      final first = cache.build(('text', 1), make);
      final second = cache.build(('text', 1), make);

      expect(identical(first, second), isTrue);
      expect(made, 1);
    });

    test('other inputs give a new span', () {
      final cache = SpanCache();
      var made = 0;
      TextSpan make() => TextSpan(text: 'span ${++made}');

      final first = cache.build(('text', 1), make);
      final second = cache.build(('text', 2), make);

      expect(identical(first, second), isFalse);
      expect(made, 2);
    });

    test('only the last span is remembered', () {
      final cache = SpanCache();
      var made = 0;
      TextSpan make() => TextSpan(text: 'span ${++made}');

      cache.build('a', make);
      cache.build('b', make);
      cache.build('a', make);

      expect(made, 3);
    });
  });
}
