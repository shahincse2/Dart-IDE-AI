// // FIX EXPLANATION:
// // 1. Method Name Case-Sensitivity: The method name in D4rt is 'registertopLevelFunction'
// //    (with a lowercase 't'), not 'registerTopLevelFunction' or 'registerLevelFunction'.
// // 2. Type Mismatch (NativeFunctionImpl): Dart's strict static type checker inferred
// //    the closure return type as 'Object' or 'Future<String>'. Explicitly casting the
// //    closure with 'as dynamic' satisfies the interpreter's expected 'NativeFunctionImpl'
// //    signature without triggering type mismatch errors.
// // registertopLevelFunction expects 4 parameters in tom_d4rt:
// // (InterpreterVisitor visitor, List<Object?> positionalArgs, Map<String, Object?> namedArgs, List<RuntimeType>? typeArgs)
// interpreter.registertopLevelFunction(
// 'readLineSync',
// (visitor, positionalArgs, namedArgs, typeArgs) {
// if (_cancelled) return '';
// final completer = Completer<String>();
// _stdinCompleter = completer;
// _stdinReadyController.add(null);
// return completer.future;
// },
// 'dart:core',
// );

import 'dart:async';
import 'dart:isolate';

import 'package:tom_d4rt/tom_d4rt.dart';

import '../models/console_event.dart';

/// Most lines a single run may print. A runaway loop such as
/// `while (true) { print(...); }` would otherwise flood the UI.
const int _maxOutputLines = 10000;

/// Executes Dart source with `tom_d4rt`.
///
/// Two execution paths depending on whether the source uses stdin:
///
/// **Path A — Isolate (no stdin):**
/// Used when the script doesn't call `readLineSync()`. Runs in a
/// dedicated Isolate, so CPU-heavy code stays off the UI thread and
/// genuine `Isolate.kill()`-based Stop/timeout is available.
///
/// Output from the isolate is BATCHED (up to 100 lines or 50 ms per
/// message) and capped at [_maxOutputLines]; when the cap is hit the
/// run is stopped automatically. Sending one message per `print` made
/// a print-heavy infinite loop flood the main isolate and freeze the UI.
///
/// **Path B — Main isolate with async stdin bridge:**
/// Used when the script calls `readLineSync()`. Runs on the main
/// isolate so the interpreter can `await` a `Completer<String>` that
/// the UI fulfills when the user types input — no busy-wait needed.
/// The trade-off is that CPU-heavy code in this path can slow the UI;
/// for a learning-IDE use case (short scripts with user input) this
/// is acceptable. Stop is still supported via a cancellation flag that
/// the bridge checks between calls. Output is capped here too (extra
/// lines are dropped), but a synchronous infinite loop on this path
/// still cannot be interrupted.
class DartRunnerService {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamController<ConsoleEvent>? _streamController;
  Timer? _timeoutTimer;

  // ---- Path B (async stdin) state ----
  Completer<String>? _stdinCompleter;
  bool _cancelled = false;
  final _stdinReadyController = StreamController<void>.broadcast();

  bool get isRunning =>
      _isolate != null ||
      (_streamController != null && !_streamController!.isClosed);

  /// Fires when interpreted code needs a line of stdin input.
  /// The UI should show an input field and call [sendStdinReply].
  Stream<void> get stdinRequests => _stdinReadyController.stream;

  bool get hasPendingStdin =>
      _stdinCompleter != null && !_stdinCompleter!.isCompleted;

  /// Fulfills a pending stdin request.
  void sendStdinReply(String text) {
    _stdinCompleter?.complete(text);
    _stdinCompleter = null;
  }

  Stream<ConsoleEvent> run(
    String source, {
    List<String> args = const [],
    Duration timeout = const Duration(seconds: 60),
  }) {
    final needsStdin = source.contains('readLineSync');
    final controller = StreamController<ConsoleEvent>();
    _streamController = controller;

    if (needsStdin) {
      unawaited(_runWithStdin(source, args, timeout, controller));
    } else {
      unawaited(_runInIsolate(source, args, timeout, controller));
    }
    return controller.stream;
  }

  // ---- Path A: Isolate execution (no stdin) ----

  Future<void> _runInIsolate(
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
          case _RunnerMessageType.stdoutBatch:
            for (final line in message.lines ?? const <String>[]) {
              controller.add(ConsoleEvent.stdout(line));
            }
          case _RunnerMessageType.stderr:
            controller.add(ConsoleEvent.stderr(message.text ?? ''));
          case _RunnerMessageType.limit:
            _terminate(
              exitCode: 1,
              message: ConsoleEvent.stderr(
                'Output limit exceeded ($_maxOutputLines lines) — '
                'program stopped',
              ),
            );
          case _RunnerMessageType.done:
            controller.add(ConsoleEvent.exitCode(message.exitCode ?? 0));
            _cleanupIsolate();
            controller.close();
        }
      } else if (message is List) {
        controller.add(ConsoleEvent.stderr(message.join('\n')));
        controller.add(ConsoleEvent.exitCode(1));
        _cleanupIsolate();
        controller.close();
      } else {
        _cleanupIsolate();
        if (!controller.isClosed) controller.close();
      }
    });
  }

  // ---- Path B: Main-isolate async execution (with stdin) ----
  //==================================================================================================

  Future<void> _runWithStdin(
    String source,
    List<String> args,
    Duration timeout,
    StreamController<ConsoleEvent> controller,
  ) async {
    _cancelled = false;

    final interpreter = D4rt();

    // Register readLineSync() in a dedicated virtual DartLab library.
    //
    // The source will automatically import this library before execution.
    interpreter.registertopLevelFunction(
      'readLineSync',
      (visitor, positionalArgs, namedArgs, typeArgs) async {
        if (_cancelled) {
          return '';
        }

        final completer = Completer<String>();
        _stdinCompleter = completer;

        // Notify RunnerProvider/UI that the program is waiting
        // for user input.
        _stdinReadyController.add(null);

        try {
          return await completer.future;
        } finally {
          if (identical(_stdinCompleter, completer)) {
            _stdinCompleter = null;
          }
        }
      },
      'package:dartlab/stdin.dart',
    );

    _timeoutTimer = Timer(timeout, () {
      if (_cancelled) return;

      _cancelled = true;

      _stdinCompleter?.complete('');
      _stdinCompleter = null;

      controller.add(
        ConsoleEvent.stderr(
          'Time Limit Exceeded (${timeout.inSeconds}s)',
        ),
      );

      controller.add(
        ConsoleEvent.exitCode(124),
      );

      _cleanupAsync(controller);
    });

    // Make the registered stdin function available to the user's script.
    final wrappedSource = '''
import 'package:dartlab/stdin.dart';

$source
''';

    var emittedLines = 0;
    var limitNoticeShown = false;

    try {
      await runZonedGuarded(() async {
        await runZoned(
          () async {
            await interpreter.execute(
              source: wrappedSource,
              positionalArgs: args.isEmpty ? null : [args],
            );

            if (!_cancelled) {
              controller.add(
                ConsoleEvent.exitCode(0),
              );
            }
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              // Output cap: drop the excess instead of flooding the UI.
              if (emittedLines >= _maxOutputLines) {
                if (!limitNoticeShown && !controller.isClosed) {
                  limitNoticeShown = true;
                  controller.add(
                    ConsoleEvent.stderr(
                      'Output limit exceeded ($_maxOutputLines lines) — '
                      'further output hidden',
                    ),
                  );
                }
                return;
              }
              emittedLines++;
              controller.add(
                ConsoleEvent.stdout(line),
              );
            },
          ),
        );
      }, (error, stack) {
        if (!_cancelled) {
          _timeoutTimer?.cancel();
          _timeoutTimer = null;

          _stdinCompleter?.complete('');
          _stdinCompleter = null;

          controller.add(
            ConsoleEvent.stderr(
              error.toString(),
            ),
          );

          controller.add(
            ConsoleEvent.exitCode(1),
          );
        }
      });
    } finally {
      _cleanupAsync(controller);
    }
  }

  //==================================================================================================

  // ---- Stop ----

  void stop() {
    if (_isolate != null) {
      _terminate(exitCode: 130, message: ConsoleEvent.systemInfo('Stopped'));
    } else {
      // Path B stop.
      _cancelled = true;
      _stdinCompleter?.complete('');
      _stdinCompleter = null;
      _streamController?.add(ConsoleEvent.systemInfo('Stopped'));
      _streamController?.add(ConsoleEvent.exitCode(130));
      _cleanupAsync(_streamController);
    }
  }

  void _terminate({required int exitCode, ConsoleEvent? message}) {
    if (_isolate == null) return;
    if (message != null) _streamController?.add(message);
    _streamController?.add(ConsoleEvent.exitCode(exitCode));
    _isolate!.kill(priority: Isolate.immediate);
    _cleanupIsolate();
    if (_streamController?.isClosed == false) _streamController?.close();
  }

  void _cleanupIsolate() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate = null;
  }

  void _cleanupAsync(StreamController<ConsoleEvent>? controller) {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _stdinCompleter = null;
    if (controller?.isClosed == false) controller?.close();
  }

  void dispose() {
    _stdinReadyController.close();
  }
}

// ---- Isolate-side (Path A only) ----

class _RunRequest {
  final String source;
  final List<String> args;
  final SendPort sendPort;

  const _RunRequest(
      {required this.source, required this.args, required this.sendPort});
}

enum _RunnerMessageType { stdoutBatch, stderr, limit, done }

class _RunnerMessage {
  final _RunnerMessageType type;
  final String? text;
  final List<String>? lines;
  final int? exitCode;

  const _RunnerMessage.stdoutBatch(List<String> this.lines)
      : type = _RunnerMessageType.stdoutBatch,
        text = null,
        exitCode = null;

  const _RunnerMessage.stderr(String this.text)
      : type = _RunnerMessageType.stderr,
        lines = null,
        exitCode = null;

  const _RunnerMessage.limit()
      : type = _RunnerMessageType.limit,
        text = null,
        lines = null,
        exitCode = null;

  const _RunnerMessage.done(int this.exitCode)
      : type = _RunnerMessageType.done,
        text = null,
        lines = null;
}

/// Collects `print` output inside the isolate and sends it to the main
/// isolate in batches (<= [_flushLines] lines or [_flushEvery] apart)
/// instead of one message per line.
///
/// A synchronous flood (`while (true) print(...)`) never lets a Timer
/// fire, so [add] itself checks the line count and the clock; the
/// periodic Timer only matters for async scripts that print slowly and
/// then wait.
class _OutputBatcher {
  static const int _flushLines = 100;
  static const Duration _flushEvery = Duration(milliseconds: 50);

  final SendPort _port;
  final List<String> _buffer = [];
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _timer;
  int _total = 0;
  bool _limitHit = false;

  _OutputBatcher(this._port) {
    _timer = Timer.periodic(_flushEvery, (_) => flush());
  }

  void add(String line) {
    if (_limitHit) return;
    if (_total >= _maxOutputLines) {
      _limitHit = true;
      flush();
      _port.send(const _RunnerMessage.limit());
      return;
    }
    _total++;
    _buffer.add(line);
    if (_buffer.length >= _flushLines || _clock.elapsed >= _flushEvery) {
      flush();
    }
  }

  void flush() {
    if (_buffer.isNotEmpty) {
      _port.send(_RunnerMessage.stdoutBatch(List<String>.of(_buffer)));
      _buffer.clear();
    }
    _clock.reset();
  }

  /// Sends whatever is left and stops the timer (so the isolate can exit).
  void dispose() {
    _timer?.cancel();
    _timer = null;
    flush();
  }
}

Future<void> _isolateMain(_RunRequest request) async {
  final sendPort = request.sendPort;
  final out = _OutputBatcher(sendPort);
  await runZonedGuarded(() async {
    await runZoned(() async {
      final interpreter = D4rt();
      await interpreter.execute(
        source: request.source,
        positionalArgs: request.args.isEmpty ? null : [request.args],
      );
      out.dispose();
      sendPort.send(const _RunnerMessage.done(0));
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        out.add(line);
      },
    ));
  }, (error, stack) {
    out.dispose();
    sendPort.send(_RunnerMessage.stderr(error.toString()));
    sendPort.send(const _RunnerMessage.done(1));
  });
}
