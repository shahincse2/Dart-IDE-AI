import 'dart:async';

import 'package:flutter/material.dart';

import '../models/console_event.dart';
import '../services/dart_runner_service.dart';
import '../services/eval_service.dart';

/// Execution state for the currently open file. The Console panel
/// (Phase 4) reads [events] the same way this provider exposes them.
class RunnerProvider extends ChangeNotifier {
  final DartRunnerService _service;
  final EvalService evalService;
  final List<ConsoleEvent> _events = [];
  StreamSubscription<ConsoleEvent>? _subscription;
  bool _isRunning = false;

  // Keep the last-run source + args so EvalService can re-run it on
  // the main isolate for post-execution variable inspection (Phase 12).
  String _lastSource = '';
  List<String> _lastArgs = const [];

  RunnerProvider({DartRunnerService? service, EvalService? evalService})
      : _service = service ?? DartRunnerService(),
        evalService = evalService ?? EvalService();

  List<ConsoleEvent> get events => List.unmodifiable(_events);
  bool get isRunning => _isRunning;

  Future<void> run(String source, {List<String> args = const []}) async {
    await _subscription?.cancel();
    _events.clear();
    _isRunning = true;
    _lastSource = source;
    _lastArgs = args;
    // Clear any session from a previous run so the inspector doesn't
    // show stale state while the new run is in progress.
    evalService.clearSession();
    notifyListeners();

    _subscription = _service.run(source, args: args).listen(
      (event) {
        _events.add(event);
        if (event.type == ConsoleEventType.exitCode) {
          _isRunning = false;
          // Only set up an eval session if the script finished cleanly —
          // a crashed or timed-out script left the environment in an
          // unknown state so eval results would be misleading.
          if (event.exitCode == 0) {
            // Don't await — let the session build in the background.
            // isSettingUp is available on evalService for UIs that want
            // to show a spinner while re-execution runs.
            unawaited(evalService.setupSession(_lastSource, args: _lastArgs));
          }
        }
        notifyListeners();
      },
      onDone: () {
        _isRunning = false;
        notifyListeners();
      },
    );
  }

  void stop() => _service.stop();

  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
