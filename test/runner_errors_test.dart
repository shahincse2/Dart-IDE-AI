import 'package:dartlab/services/runner/runner_errors.dart';
import 'package:flutter_test/flutter_test.dart';

const parseError = 'SourceCodeException: Fatal parsing errors for the direct '
    'source:\n- The await expression can only be used in an async function. '
    "(line 4, column 11)\nProblematic code: [import 'x'; class A {}]";

void main() {
  group('friendlyRunError', () {
    test('drops the dump of the program but keeps the line number', () {
      final text = friendlyRunError(parseError);

      expect(text, isNot(contains('Problematic code')));
      expect(text, isNot(contains('class A')));
      expect(text, contains('line 4'));
    });

    test('adds a hint for await outside an async function', () {
      expect(friendlyRunError(parseError),
          contains('await can only be used inside a function marked async'));
    });

    test('other errors pass through unchanged', () {
      expect(friendlyRunError('Runtime Error: boom'), 'Runtime Error: boom');
    });
  });
}
