import 'dart:async';
import 'dart:isolate';

import '../../models/console_event.dart';
import 'isolate_entry.dart';
import 'runner_limits.dart';
import 'runner_messages.dart';

/// Runs a program in a dedicated Isolate (programs that need no stdin).
///
/// CPU-heavy code stays off the UI thread, and `Isolate.kill()` gives a
/// genuine Stop / time limit, even for an endless loop.
class IsolateRunner {
  Isolate? _isolate;
  ReceivePort? _port;
  Timer? _timeout;
  StreamController<ConsoleEvent>? _controller;

  bool get isActive => _isolate != null;

  Future<void> run({
    required String source,
    required List<String> args,
    required Duration timeout,
    required StreamController<ConsoleEvent> controller,
  }) async {
    _controller = controller;
    final port = ReceivePort();
    _port = port;

    try {
      _isolate = await Isolate.spawn(
        isolateMain,
        RunRequest(source: source, args: args, sendPort: port.sendPort),
        onError: port.sendPort,
        onExit: port.sendPort,
      );
    } catch (e) {
      controller.add(ConsoleEvent.stderr('Failed to start interpreter: $e'));
      controller.add(ConsoleEvent.exitCode(1));
      _cleanup();
      await controller.close();
      return;
    }

    _timeout = Timer(
      timeout,
      () => _terminate(
        exitCode: 124,
        message:
            ConsoleEvent.stderr('Time Limit Exceeded (${timeout.inSeconds}s)'),
      ),
    );
    port.listen(_onMessage);
  }

  void stop() => _terminate(
        exitCode: 130,
        message: ConsoleEvent.systemInfo('Stopped'),
      );

  void _onMessage(Object? message) {
    final controller = _controller;
    if (controller == null) return;

    if (message is RunnerMessage) {
      switch (message.type) {
        case RunnerMessageType.stdoutBatch:
          for (final line in message.lines ?? const <String>[]) {
            controller.add(ConsoleEvent.stdout(line));
          }
        case RunnerMessageType.stderr:
          controller.add(ConsoleEvent.stderr(message.text ?? ''));
        case RunnerMessageType.limit:
          _terminate(
            exitCode: 1,
            message: ConsoleEvent.stderr(
              'Output limit exceeded ($kMaxOutputLines lines) — '
              'program stopped',
            ),
          );
        case RunnerMessageType.done:
          controller.add(ConsoleEvent.exitCode(message.exitCode ?? 0));
          _cleanup();
          controller.close();
      }
    } else if (message is List) {
      // Uncaught error reported by the isolate itself (onError).
      controller.add(ConsoleEvent.stderr(message.join('\n')));
      controller.add(ConsoleEvent.exitCode(1));
      _cleanup();
      controller.close();
    } else {
      // onExit (null).
      _cleanup();
      if (!controller.isClosed) controller.close();
    }
  }

  void _terminate({required int exitCode, ConsoleEvent? message}) {
    if (_isolate == null) return;
    final controller = _controller;
    if (message != null) controller?.add(message);
    controller?.add(ConsoleEvent.exitCode(exitCode));
    _isolate!.kill(priority: Isolate.immediate);
    _cleanup();
    if (controller != null && !controller.isClosed) controller.close();
  }

  void _cleanup() {
    _timeout?.cancel();
    _timeout = null;
    _port?.close();
    _port = null;
    _isolate = null;
  }
}
