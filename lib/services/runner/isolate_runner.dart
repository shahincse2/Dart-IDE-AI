import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../models/console_event.dart';
import 'isolate_entry.dart';
import 'run_timer.dart';
import 'runner_limits.dart';
import 'runner_messages.dart';
import 'stdin_bridge.dart';
import 'stdin_mailbox.dart';

/// Runs a program in a dedicated Isolate, so `Isolate.kill()` gives a genuine
/// Stop / time limit even for an endless loop or a program blocked waiting
/// for input. The time limit is paused while the program waits for the user.
class IsolateRunner {
  IsolateRunner(this._stdin);

  final StdinBridge _stdin;
  final RunTimer _timer = RunTimer();
  Isolate? _isolate;
  ReceivePort? _port;
  Directory? _mailDir;
  StreamSubscription<bool>? _waitingSub;
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
      final dir = Directory.systemTemp.createTempSync('dartlab_run_');
      _mailDir = dir;
      _stdin.attach(StdinMailbox(dir.path).deliver);
      _isolate = await Isolate.spawn(
        isolateMain,
        RunRequest(
          source: source,
          args: args,
          sendPort: port.sendPort,
          stdinDir: dir.path,
        ),
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

    _waitingSub = _stdin.waitingChanges
        .listen((waiting) => waiting ? _timer.pause() : _timer.resume());
    _timer.start(
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
        case RunnerMessageType.stdinRequest:
          _stdin.requestLine();
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
    _waitingSub?.cancel();
    _waitingSub = null;
    _timer.cancel();
    _stdin.detach();
    _port?.close();
    _port = null;
    _isolate = null;

    final dir = _mailDir;
    _mailDir = null;
    try {
      dir?.deleteSync(recursive: true);
    } on FileSystemException {
      // Only temporary files: the system cleans them up eventually.
    }
  }
}
