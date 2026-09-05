import 'dart:async';
import 'dart:isolate';

import 'package:tom_d4rt/tom_d4rt.dart';

import '../models/console_event.dart';

/// Executes Dart source with `tom_d4rt`, one run per call.
///
/// Runs inside a dedicated [Isolate] rather than directly on the UI
/// isolate, for two real (not cosmetic) reasons:
///   1. Interpreting arbitrary user code can be CPU-heavy; an Isolate
///      keeps that off the UI thread so the app stays responsive.
///   2. `tom_d4rt`'s public API has no `cancel()`/`stop()` method (we
///      checked before writing this). `Isolate.kill()` is the only
///      genuine way to terminate a run in progress — `Future.timeout()`
///      alone would just stop *waiting*, leaving the interpretation
///      running in the background. Section 32/33 explicitly rule that
///      out, so this is built as an Isolate from the start.
///
/// stdout is captured via a `Zone`-level `print` override — a
/// language-level mechanism, not something specific to this package —
/// so it works regardless of how the interpreter itself implements
/// `print()` internally.
class DartRunnerService {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamController<ConsoleEvent>? _controller;
  Timer? _timeoutTimer;

  bool get isRunning => _isolate != null;

  /// Starts a run and returns a stream of [ConsoleEvent]s. The stream
  /// always ends with an exitCode event (0 on success, non-zero on
  /// error/timeout/stop) followed by the stream closing.
  Stream<ConsoleEvent> run(
    String source, {
    List<String> args = const [],
    Duration timeout = const Duration(seconds: 10),
  }) {
    final controller = StreamController<ConsoleEvent>();
    _controller = controller;
    unawaited(_start(source, args, timeout, controller));
    return controller.stream;
  }

  /// Requests early termination (Section 33's Stop button). Genuinely
  /// kills the isolate rather than merely abandoning a Future.
  void stop() =>
      _terminate(exitCode: 130, message: ConsoleEvent.systemInfo('Stopped'));

  Future<void> _start(
    String source,
    List<String> args,
    Duration timeout,
    StreamController<ConsoleEvent> controller,
  ) async {
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    try {
      _isolate = await Isolate.spawn(
        _isolateMain,
        _RunRequest(source: source, args: args, sendPort: receivePort.sendPort),
        onError: receivePort.sendPort,
        onExit: receivePort.sendPort,
      );
    } catch (e) {
      controller.add(ConsoleEvent.stderr('Failed to start interpreter: $e'));
      controller.add(ConsoleEvent.exitCode(1));
      await controller.close();
      return;
    }

    _timeoutTimer = Timer(timeout, () {
      _terminate(
        exitCode: 124,
        message:
            ConsoleEvent.stderr('Time Limit Exceeded (${timeout.inSeconds}s)'),
      );
    });

    receivePort.listen((message) {
      if (message is _RunnerMessage) {
        switch (message.type) {
          case _RunnerMessageType.stdout:
            controller.add(ConsoleEvent.stdout(message.text ?? ''));
          case _RunnerMessageType.stderr:
            controller.add(ConsoleEvent.stderr(message.text ?? ''));
          case _RunnerMessageType.done:
            controller.add(ConsoleEvent.exitCode(message.exitCode ?? 0));
            _cleanup();
            controller.close();
        }
      } else if (message is List) {
        // onError delivers [errorString, stackTraceString].
        controller.add(ConsoleEvent.stderr(message.join('\n')));
        controller.add(ConsoleEvent.exitCode(1));
        _cleanup();
        controller.close();
      } else {
        // onExit fired (message == null) after we already reported a
        // result via _terminate() or the done case above — nothing
        // further to add.
        _cleanup();
        if (!controller.isClosed) controller.close();
      }
    });
  }

  /// Kills the running isolate and reports why, so "Program finished
  /// (exit code N)" alone never has to speak for a Stop/timeout — the
  /// preceding message says what actually happened.
  void _terminate({required int exitCode, ConsoleEvent? message}) {
    if (_isolate == null) return;
    if (message != null) _controller?.add(message);
    _controller?.add(ConsoleEvent.exitCode(exitCode));
    _isolate!.kill(priority: Isolate.immediate);
    _cleanup();
    if (_controller?.isClosed == false) _controller?.close();
  }

  void _cleanup() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate = null;
  }
}

// ---- Isolate-side: everything below runs on the spawned isolate ----

class _RunRequest {
  final String source;
  final List<String> args;
  final SendPort sendPort;
  const _RunRequest(
      {required this.source, required this.args, required this.sendPort});
}

enum _RunnerMessageType { stdout, stderr, done }

class _RunnerMessage {
  final _RunnerMessageType type;
  final String? text;
  final int? exitCode;

  const _RunnerMessage.stdout(String this.text)
      : type = _RunnerMessageType.stdout,
        exitCode = null;

  const _RunnerMessage.stderr(String this.text)
      : type = _RunnerMessageType.stderr,
        exitCode = null;

  const _RunnerMessage.done(int this.exitCode)
      : type = _RunnerMessageType.done,
        text = null;
}

Future<void> _isolateMain(_RunRequest request) async {
  final sendPort = request.sendPort;
  await runZonedGuarded(() async {
    await runZoned(() async {
      final interpreter = D4rt();
      await interpreter.execute(
        source: request.source,
        positionalArgs: request.args.isEmpty ? null : [request.args],
      );
      sendPort.send(const _RunnerMessage.done(0));
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        sendPort.send(_RunnerMessage.stdout(line));
      },
    ));
  }, (error, stack) {
    // DIAGNOSTIC (temporary): the plain exception message (e.g.
    // RangeError's toString()) confirmed to carry no line info at all
    // — that's normal Dart behavior, not specific to tom_d4rt. This
    // prints the stack trace too, purely to check whether IT has
    // anything usable. Meant to come back out once we know either way
    // — see runner_error_parser.dart.
    sendPort.send(_RunnerMessage.stderr(
        '${error.toString()}\n[stack trace — diagnostic]\n$stack'));
    sendPort.send(const _RunnerMessage.done(1));
  });
}
