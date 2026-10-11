/// Virtual library that holds the native half of console I/O.
const String kConsoleIoLibrary = 'package:dartlab/console_io.dart';

/// Dart source that gives a program `stdout`, `stderr`, `stdin` and `exit`.
///
/// It is appended to the user's program (declarations may appear in any
/// order, so the user's line numbers stay untouched) and is built only on
/// the functions registered by `bindConsoleIo`. Nothing here reaches the
/// real `dart:io`: output goes to the DartLab console, input comes from
/// the console's input bar, and `exit` ends only the program, never the app.
///
/// `stdin.readLineSync()` really blocks (the program's own isolate waits for
/// the line), so it works anywhere: in `main`, in helper functions, in
/// getters, in callbacks.
const String kConsoleIoPrelude = r'''
// ---- DartLab console I/O (added automatically) ----
class _DartLabOutput {
  _DartLabOutput(this._isError);
  final bool _isError;

  void _emit(String text) {
    if (_isError) {
      dartlabWriteErr(text);
    } else {
      dartlabWrite(text);
    }
  }

  void write(Object? object) => _emit('$object');
  void writeln([Object? object = '']) => _emit('$object\n');
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _emit(objects.join(separator));
  void writeCharCode(int charCode) => _emit(String.fromCharCode(charCode));
  Future<void> flush() async {}
}

class _DartLabInput {
  String? readLineSync({Object? encoding, bool retainNewlines = false}) {
    final line = dartlabReadLine();
    return retainNewlines ? '$line\n' : line;
  }
}

final stdout = _DartLabOutput(false);
final stderr = _DartLabOutput(true);
final stdin = _DartLabInput();

void exit(int code) => dartlabExit(code);
''';
