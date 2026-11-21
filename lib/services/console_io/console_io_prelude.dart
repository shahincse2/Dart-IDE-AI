/// Virtual library that holds the native half of console I/O.
const String kConsoleIoLibrary = 'package:dart_ide/console_io.dart';

/// Dart source that gives a program `stdout`, `stderr`, `stdin` and `exit`.
///
/// It is appended to the user's program (declarations may appear in any
/// order, so the user's line numbers stay untouched) and is built only on
/// the functions registered by `bindConsoleIo`. Nothing here reaches the
/// real `dart:io`: output goes to the Dart IDE console, input comes from
/// the console's input bar, and `exit` ends only the program, never the app.
///
/// `stdin.readLineSync()` really blocks (the program's own isolate waits for
/// the line), so it works anywhere: in `main`, in helper functions, in
/// getters, in callbacks.
const String kConsoleIoPrelude = r'''
// ---- Dart IDE console I/O (added automatically) ----
class _DartIdeOutput {
  _DartIdeOutput(this._isError);
  final bool _isError;

  void _emit(String text) {
    if (_isError) {
      dartIdeWriteErr(text);
    } else {
      dartIdeWrite(text);
    }
  }

  void write(Object? object) => _emit('$object');
  void writeln([Object? object = '']) => _emit('$object\n');
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _emit(objects.join(separator));
  void writeCharCode(int charCode) => _emit(String.fromCharCode(charCode));
  Future<void> flush() async {}
}

class _DartIdeInput {
  String? readLineSync({Object? encoding, bool retainNewlines = false}) {
    final line = dartIdeReadLine();
    return retainNewlines ? '$line\n' : line;
  }
}

final stdout = _DartIdeOutput(false);
final stderr = _DartIdeOutput(true);
final stdin = _DartIdeInput();

void exit(int code) => dartIdeExit(code);
''';
