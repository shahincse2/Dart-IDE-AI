/// Virtual library that holds the native half of console I/O.
const String kConsoleIoLibrary = 'package:dartlab/console_io.dart';

/// Dart source that gives a program `stdout`, `stderr` and `stdin`.
///
/// It is appended to the user's program (declarations may appear in any
/// order, so the user's line numbers stay untouched) and is built only on
/// the functions registered by `bindConsoleIo`. Nothing here reaches the
/// real `dart:io`: output goes to the DartLab console, input comes from
/// the console's input bar.
///
/// `stdin.readLineSync()` is asynchronous here (the program has to wait for
/// the user to type); `ConsoleIoSource` adds the `await` for the program.
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
  Future<String?> readLineSync({Object? encoding, bool retainNewlines = false}) async {
    final line = await dartlabReadLine();
    return retainNewlines ? '$line\n' : line;
  }
}

final stdout = _DartLabOutput(false);
final stderr = _DartLabOutput(true);
final stdin = _DartLabInput();
''';
