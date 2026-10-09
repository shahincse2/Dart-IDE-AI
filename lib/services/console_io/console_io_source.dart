import 'console_io_prelude.dart';

/// The outcome of [ConsoleIoSource.prepare].
class PreparedSource {
  const PreparedSource.ok(this.source, {this.needsStdin = false})
      : error = null;
  const PreparedSource.failed(String this.error)
      : source = '',
        needsStdin = false;

  /// What to hand to the interpreter.
  final String source;

  /// A learner-friendly reason the program cannot run, or null.
  final String? error;

  /// True when the program reads input, so it has to run where the UI can
  /// answer the request.
  final bool needsStdin;
}

/// Lets ordinary console programs run without exposing the real `dart:io`.
///
/// For a program that imports `dart:io` this
///   * refuses anything except `stdin`, `stdout` and `stderr`,
///   * turns the import into a comment (same line, so line numbers hold),
///   * adds `await` to `stdin.readLineSync()` and makes `main` async,
///   * appends the DartLab `stdout`/`stderr`/`stdin` implementation.
/// Programs that use neither `dart:io` nor `readLineSync` pass through as is.
class ConsoleIoSource {
  ConsoleIoSource._();

  static const _allowedNames = {'stdin', 'stdout', 'stderr'};

  static const _sandboxNote = 'DartLab runs programs in a sandbox: from '
      'dart:io only stdin, stdout and stderr are available. File, network '
      'and process access is switched off for your safety.';

  static final _dartIoImport = RegExp(
    r'''^[ \t]*import\s+['"]dart:io['"]([^;]*);''',
    multiLine: true,
  );
  static final _stdinRead =
      RegExp(r'\bstdin\s*\.\s*readLineSync\s*\(([^()]*)\)');
  static final _endsWithAwait = RegExp(r'\bawait\s*$');
  static final _mainDeclaration = RegExp(
    r'^[ \t]*(?:void\s+|Future<void>\s+|Future\s+)?main\s*\(([^)]*)\)\s*(async\s*)?\{',
    multiLine: true,
  );
  static final _unsupportedUse = RegExp(
    r'\b(?:File|Directory|Link|Process|HttpClient|HttpServer|ServerSocket|WebSocket|RandomAccessFile)\s*[.(]'
    r'|\b(?:Platform|Socket|InternetAddress)\s*\.'
    r'|\b(?:exit|sleep)\s*\(',
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
      final awaited = _awaitStdinReads(code);
      code = awaited == code ? code : _makeMainAsync(awaited);
      withPrelude = true;
    }

    // The import goes on the SAME line as the user's first line, so line
    // numbers in error messages still match the editor.
    final header = "import '$kConsoleIoLibrary'; ";
    final tail = withPrelude ? '\n\n$kConsoleIoPrelude' : '';
    return PreparedSource.ok(
      '$header$code$tail',
      needsStdin: code.contains('readLineSync'),
    );
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
    return '$_sandboxNote (Not available: ${hit.group(0)!.trim()})';
  }

  static String _removeImports(String code) =>
      code.replaceAllMapped(_dartIoImport, (match) {
        final lineBreaks = '\n'.allMatches(match.group(0)!).length;
        return '// dart:io is provided by DartLab${'\n' * lineBreaks}';
      });

  static String _awaitStdinReads(String code) =>
      code.replaceAllMapped(_stdinRead, (match) {
        final before = code.substring(0, match.start);
        if (_endsWithAwait.hasMatch(before)) return match.group(0)!;
        return '(await stdin.readLineSync(${match.group(1)}))';
      });

  static String _makeMainAsync(String code) =>
      code.replaceFirstMapped(_mainDeclaration, (match) {
        if (match.group(2) != null) return match.group(0)!; // already async
        final text = match.group(0)!;
        final indent = text.substring(0, text.length - text.trimLeft().length);
        return '${indent}Future<void> main(${match.group(1)}) async {';
      });
}
