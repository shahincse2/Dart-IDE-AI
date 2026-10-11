import 'console_io_prelude.dart';

/// The outcome of [ConsoleIoSource.prepare].
class PreparedSource {
  const PreparedSource.ok(this.source) : error = null;
  const PreparedSource.failed(String this.error) : source = '';

  /// What to hand to the interpreter.
  final String source;

  /// A learner-friendly reason the program cannot run, or null.
  final String? error;
}

/// Lets ordinary console programs run without exposing the real `dart:io`.
///
/// For a program that imports `dart:io` this
///   * refuses anything except `stdin`, `stdout`, `stderr` and `exit`,
///   * turns the import into a comment (same line, so line numbers hold),
///   * appends the DartLab implementation of those four.
/// Programs that use neither `dart:io` nor `readLineSync` pass through as is.
class ConsoleIoSource {
  ConsoleIoSource._();

  static const _allowedNames = {'stdin', 'stdout', 'stderr', 'exit'};

  static const _sandboxNote = 'DartLab runs programs in a sandbox: from '
      'dart:io only stdin, stdout, stderr and exit are available. File, '
      'network and process access is switched off for your safety.';

  static final _dartIoImport = RegExp(
    r'''^[ \t]*import\s+['"]dart:io['"]([^;]*);''',
    multiLine: true,
  );
  static final _unsupportedUse = RegExp(
    r'\b(?:File|Directory|Link|Process|HttpClient|HttpServer|ServerSocket|WebSocket|RandomAccessFile)\s*[.(]'
    r'|\b(?:Platform|Socket|InternetAddress)\s*\.'
    r'|\bsleep\s*\(',
  );
  static final _commentsAndStrings = RegExp(
    r'''//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*"''',
  );

  static PreparedSource prepare(String source) {
    final imports = _dartIoImport.allMatches(source).toList();
    if (imports.isEmpty && !source.contains('readLineSync')) {
      return PreparedSource.ok(source);
    }

    var code = source;
    var withPrelude = false;
    if (imports.isNotEmpty) {
      final problem = _importProblem(imports) ?? _usageProblem(source);
      if (problem != null) return PreparedSource.failed(problem);
      code = _removeImports(code);
      withPrelude = true;
    }

    // The import goes on the SAME line as the user's first line, so line
    // numbers in error messages still match the editor.
    final header = "import '$kConsoleIoLibrary'; ";
    final tail = withPrelude ? '\n\n$kConsoleIoPrelude' : '';
    return PreparedSource.ok('$header$code$tail');
  }

  static String? _importProblem(List<RegExpMatch> imports) {
    for (final match in imports) {
      final modifier = (match.group(1) ?? '').trim();
      if (modifier.isEmpty) continue;
      if (modifier.startsWith('show')) {
        final extra = modifier
            .substring(4)
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty && !_allowedNames.contains(name))
            .toList();
        if (extra.isEmpty) continue;
        return '$_sandboxNote (Not available: ${extra.join(', ')})';
      }
      return "$_sandboxNote Please use a plain import 'dart:io'; — "
          "'as' and 'hide' are not supported.";
    }
    return null;
  }

  static String? _usageProblem(String source) {
    final code = source.replaceAll(_commentsAndStrings, ' ');
    final hit = _unsupportedUse.firstMatch(code);
    if (hit == null) return null;
    final name = hit.group(0)!.replaceAll(RegExp(r'[\s.(]+$'), '');
    return '$_sandboxNote (Not available: $name)';
  }

  static String _removeImports(String code) =>
      code.replaceAllMapped(_dartIoImport, (match) {
        final lineBreaks = '\n'.allMatches(match.group(0)!).length;
        return '// dart:io is provided by DartLab${'\n' * lineBreaks}';
      });
}
