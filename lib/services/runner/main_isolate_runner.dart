import 'dart:async';

import 'package:tom_d4rt/tom_d4rt.dart';

import '../../models/console_event.dart';
import '../console_io/console_io_binding.dart';
import '../console_io/line_console_sink.dart';
import 'runner_errors.dart';
import 'runner_limits.dart';
import 'stdin_bridge.dart';

/// Runs a program on the main isolate (programs that read input).
///
/// The interpreter can then `await` a line typed in the console's input bar
/// without any busy-waiting. Trade-off: CPU-heavy code here can slow the
/// UI, and a synchronous endless loop cannot be interrupted. Stop works
/// while the program waits for input, see [StdinBridge.cancel].
class MainIsolateRunner {
  MainIsolateRunner(this._stdin);

  final StdinBridge _stdin;
  Timer? _timeout;
  StreamSubscription<bool>? _waitingSub;

  Future<void> run({
    required String source,
    required List<String> args,
    required Duration timeout,
    required StreamController<ConsoleEvent> controller,
  }) async {
    _stdin.reset();

    var shown = 0;
    var announced = false;
    void emit(ConsoleEvent event) {
      if (controller.isClosed) return;
      if (shown >= kMaxOutputLines) {
        if (announced) return;
        announced = true;
        event = ConsoleEvent.stderr(
          'Output limit exceeded ($kMaxOutputLines lines) — '
          'further output hidden',
        );
      } else {
        shown++;
      }
      controller.add(event);
    }

    final sink = LineConsoleSink(
      onOutLine: (line) => emit(ConsoleEvent.stdout(line)),
      onErrLine: (line) => emit(ConsoleEvent.stderr(line)),
    );

    final interpreter = D4rt();
    bindConsoleIo(
      interpreter,
      sink,
      // A prompt written with stdout.write() must show before we wait.
      readLine: () {
        sink.flush();
        return _stdin.readLine();
      },
    );

    // The time limit counts RUNNING time only: it is paused while the
    // program waits for the user, and starts afresh after every answer.
    void startTimer() {
      _timeout?.cancel();
      _timeout = Timer(timeout, () {
        if (_stdin.isCancelled) return;
        _stdin.cancel();
        controller.add(
          ConsoleEvent.stderr('Time Limit Exceeded (${timeout.inSeconds}s)'),
        );
        controller.add(ConsoleEvent.exitCode(124));
        _finish(controller);
      });
    }

    _waitingSub = _stdin.waitingChanges.listen((waiting) {
      if (waiting) {
        _timeout?.cancel();
      } else if (!_stdin.isCancelled) {
        startTimer();
      }
    });
    startTimer();

    try {
      await runZonedGuarded(() async {
        await runZoned(() async {
          await interpreter.execute(
            source: source,
            positionalArgs: args.isEmpty ? null : [args],
          );
          if (!_stdin.isCancelled) {
            sink.flush();
            controller.add(ConsoleEvent.exitCode(0));
          }
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => sink.writeOut('$line\n'),
        ));
      }, (error, stack) {
        if (_stdin.isCancelled) return;
        _stdin.cancel();
        sink.flush();
        controller.add(
          ConsoleEvent.stderr(friendlyRunError(error, source: source)),
        );
        controller.add(ConsoleEvent.exitCode(1));
      });
    } finally {
      _finish(controller);
    }
  }

  void stop(StreamController<ConsoleEvent>? controller) {
    _stdin.cancel();
    if (controller != null && !controller.isClosed) {
      controller.add(ConsoleEvent.systemInfo('Stopped'));
      controller.add(ConsoleEvent.exitCode(130));
    }
    _finish(controller);
  }

  void _finish(StreamController<ConsoleEvent>? controller) {
    _timeout?.cancel();
    _timeout = null;
    _waitingSub?.cancel();
    _waitingSub = null;
    if (controller != null && !controller.isClosed) controller.close();
  }
}
