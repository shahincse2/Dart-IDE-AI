import 'dart:async';
import 'dart:isolate';

import 'package:tom_d4rt/tom_d4rt.dart';

import '../console_io/console_io_binding.dart';
import '../console_io/line_console_sink.dart';
import 'output_batcher.dart';
import 'runner_errors.dart';
import 'runner_messages.dart';
import 'stdin_mailbox.dart';

/// Entry point of the runner isolate. Every program runs here, so Stop and
/// the time limit work even when the program is stuck or waiting for input.
///
/// Must stay a top-level function: `Isolate.spawn` cannot take a closure.
Future<void> isolateMain(RunRequest request) async {
  final port = request.sendPort;
  final batcher = OutputBatcher(port);
  final sink = LineConsoleSink(
    onOutLine: batcher.add,
    onErrLine: batcher.addError,
  );
  final mailbox = StdinMailbox(request.stdinDir);

  void finish() {
    sink.flush();
    batcher.dispose();
  }

  // stdin.readLineSync(): show the prompt, ask the UI for a line, then
  // block this isolate (only this one) until the line arrives.
  String readLine() {
    sink.flush();
    batcher.flush();
    port.send(const RunnerMessage.stdinRequest());
    return mailbox.waitForLine();
  }

  // exit(): ends the PROGRAM (this isolate), never the app.
  void exitProgram(int code) {
    finish();
    Isolate.exit(port, RunnerMessage.done(code));
  }

  await runZonedGuarded(() async {
    await runZoned(() async {
      final interpreter = D4rt();
      bindConsoleIo(interpreter, sink, readLine: readLine, onExit: exitProgram);
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
    port.send(RunnerMessage.stderr(friendlyRunError(error)));
    port.send(const RunnerMessage.done(1));
  });
}
