import 'package:tom_d4rt/tom_d4rt.dart';

import 'console_io_prelude.dart';
import 'console_sink.dart';

/// Registers the native half of DartLab's console I/O on [interpreter].
///
/// [readLine] answers `stdin.readLineSync()` and the older bare
/// `readLineSync()`. It is allowed to block: the program runs in its own
/// isolate. [onExit] ends the program (`exit(code)`).
///
/// Only these functions are exposed to the program. It gets no file,
/// network or process access.
void bindConsoleIo(
  D4rt interpreter,
  ConsoleSink sink, {
  required String Function() readLine,
  required void Function(int exitCode) onExit,
}) {
  void register(String name, Object? Function(List<Object?> args) body) {
    interpreter.registertopLevelFunction(
      name,
      (visitor, positionalArgs, namedArgs, typeArgs) => body(positionalArgs),
      kConsoleIoLibrary,
    );
  }

  register('dartlabWrite', (args) {
    sink.writeOut(_text(args));
    return null;
  });
  register('dartlabWriteErr', (args) {
    sink.writeErr(_text(args));
    return null;
  });
  register('dartlabReadLine', (args) => readLine());
  // Kept for programs written before stdin.readLineSync() was supported.
  register('readLineSync', (args) => readLine());
  register('dartlabExit', (args) {
    onExit(_exitCode(args));
    return null;
  });
}

String _text(List<Object?> args) => args.isEmpty ? '' : '${args.first}';

int _exitCode(List<Object?> args) =>
    args.isNotEmpty && args.first is int ? args.first as int : 0;
