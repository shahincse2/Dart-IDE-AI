import 'dart:async';

import '../models/console_event.dart';
import 'console_io/console_io_source.dart';
import 'runner/isolate_runner.dart';
import 'runner/main_isolate_runner.dart';
import 'runner/runner_limits.dart';
import 'runner/stdin_bridge.dart';

/// Runs Dart source with `tom_d4rt` and reports a stream of console events.
///
/// Programs that read input run on the main isolate ([MainIsolateRunner]);
/// everything else runs in a dedicated isolate ([IsolateRunner]) so Stop
/// and the time limit always work. Both only ever see the program through
/// `ConsoleIoSource.prepare`, which is also what keeps `dart:io` (files,
/// network, processes) out of reach.
class DartRunnerService {
  final StdinBridge _stdin = StdinBridge();
  final IsolateRunner _isolateRunner = IsolateRunner();
  late final MainIsolateRunner _mainRunner = MainIsolateRunner(_stdin);
  StreamController<ConsoleEvent>? _controller;

  bool get isRunning =>
      _isolateRunner.isActive ||
      (_controller != null && !_controller!.isClosed);

  /// Fires when the program needs a line of input. The UI should show an
  /// input field and call [sendStdinReply].
  Stream<void> get stdinRequests => _stdin.requests;

  bool get hasPendingStdin => _stdin.hasPending;

  void sendStdinReply(String text) => _stdin.reply(text);

  Stream<ConsoleEvent> run(
    String source, {
    List<String> args = const [],
    Duration timeout = kDefaultRunTimeout,
  }) {
    final controller = StreamController<ConsoleEvent>();
    _controller = controller;

    final prepared = ConsoleIoSource.prepare(source);
    final error = prepared.error;
    if (error != null) {
      controller
        ..add(ConsoleEvent.stderr(error))
        ..add(ConsoleEvent.exitCode(1));
      unawaited(controller.close());
      return controller.stream;
    }

    final runner = prepared.needsStdin ? _mainRunner.run : _isolateRunner.run;
    unawaited(runner(
      source: prepared.source,
      args: args,
      timeout: timeout,
      controller: controller,
    ));
    return controller.stream;
  }

  void stop() {
    if (_isolateRunner.isActive) {
      _isolateRunner.stop();
    } else {
      _mainRunner.stop(_controller);
    }
  }

  void dispose() => _stdin.dispose();
}
