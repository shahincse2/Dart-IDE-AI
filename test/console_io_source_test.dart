import 'package:dartlab/services/console_io/console_io_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsoleIoSource.prepare', () {
    test('leaves programs without dart:io or readLineSync untouched', () {
      const code = "void main() { print('hi'); }";
      final result = ConsoleIoSource.prepare(code);

      expect(result.error, isNull);
      expect(result.source, code);
    });

    test('plain dart:io import: replaced, prelude added, lines unchanged', () {
      const code = "import 'dart:io';\n\nvoid main() {\n  stdout.writeln('x');\n}\n";
      final result = ConsoleIoSource.prepare(code);
      final lines = result.source.split('\n');

      expect(result.error, isNull);
      expect(lines[0], contains('dart:io is provided by DartLab'));
      expect(lines[2], 'void main() {'); // same line number as in the editor
      expect(result.source, contains('class _DartLabOutput'));
    });

    test('stdin.readLineSync() is left exactly as the user wrote it', () {
      const code = "import 'dart:io';\n"
          'void main() {\n'
          '  final name = stdin.readLineSync();\n'
          '}\n';
      final result = ConsoleIoSource.prepare(code);

      expect(result.error, isNull);
      expect(result.source, contains('final name = stdin.readLineSync();'));
      expect(result.source, contains('void main() {'));
      expect(result.source, isNot(contains('(await stdin')));
      expect(result.source, isNot(contains('Future<void> main')));
    });

    test('exit() is allowed, plain or with show', () {
      final plain = ConsoleIoSource.prepare(
          "import 'dart:io';\nvoid main() { exit(0); }");
      final shown = ConsoleIoSource.prepare(
          "import 'dart:io' show exit;\nvoid main() { exit(1); }");

      expect(plain.error, isNull);
      expect(shown.error, isNull);
    });

    test('show stdout is accepted, show File is refused', () {
      final ok = ConsoleIoSource.prepare(
          "import 'dart:io' show stdout;\nvoid main() { stdout.writeln(1); }");
      final bad = ConsoleIoSource.prepare(
          "import 'dart:io' show File;\nvoid main() {}");

      expect(ok.error, isNull);
      expect(bad.error, contains('File'));
    });

    test("'as' and 'hide' imports are refused", () {
      final result =
          ConsoleIoSource.prepare("import 'dart:io' as io;\nvoid main() {}");
      expect(result.error, contains('plain import'));
    });

    test('file, process and sleep are refused with a friendly message', () {
      for (final use in [
        "File('a.txt')",
        "Process.run('ls', [])",
        'sleep(Duration(seconds: 1))',
      ]) {
        final result = ConsoleIoSource.prepare(
            "import 'dart:io';\nvoid main() { $use; }");
        expect(result.error, contains('sandbox'), reason: use);
      }
    });

    test('comments and strings that mention File( are ignored', () {
      const code = "import 'dart:io';\n"
          "// File('a') is only mentioned in a comment\n"
          "void main() { print('Directory('); stdout.write('a'); }\n";
      expect(ConsoleIoSource.prepare(code).error, isNull);
    });

    test('old-style bare readLineSync() keeps working', () {
      const code = 'void main() async {\n  final a = await readLineSync();\n}\n';
      final result = ConsoleIoSource.prepare(code);

      expect(result.error, isNull);
      expect(result.source, startsWith("import 'package:dartlab/console_io.dart'; void main()"));
      expect(result.source, isNot(contains('class _DartLabOutput')));
    });
  });
}
