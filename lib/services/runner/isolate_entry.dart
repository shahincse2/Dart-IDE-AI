import 'dart:async';

import 'package:tom_d4rt/tom_d4rt.dart';

import '../console_io/console_io_binding.dart';
import '../console_io/line_console_sink.dart';
import 'output_batcher.dart';
import 'runner_messages.dart';

/// Entry point of the runner isolate (programs that need no stdin).
///
/// Must stay a top-level function: `Isolate.spawn` cannot take a closure.
Future<void> isolateMain(RunRequest request) async {
  final port = request.sendPort;
  final batcher = OutputBatcher(port);
  final sink = LineConsoleSink(
    onOutLine: batcher.add,
    onErrLine: batcher.addError,
  );

  void finish() {
    sink.flush();
    batcher.dispose();
  }

  await runZonedGuarded(() async {
    await runZoned(() async {
      final interpreter = D4rt();
      // No stdin in this path: reading just yields an empty line.
      bindConsoleIo(interpreter, sink, readLine: () async => '');
      await interpreter.execute(
        source: request.source,
        positionalArgs: request.args.isEmpty ? null : [request.args],
      );
      finish();
      port.send(const RunnerMessage.done(0));
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => sink.writeOut('$line\n'),
    ));
  }, (error, stack) {
    finish();
    port.send(RunnerMessage.stderr(error.toString()));
    port.send(const RunnerMessage.done(1));
  });
}
