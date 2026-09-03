import 'dart:async';

import 'package:flutter/material.dart';

import '../models/console_event.dart';
import '../services/dart_runner_service.dart';

/// Execution state for the currently open file. The Console panel
/// (Phase 4) reads [events] the same way this provider exposes them —
/// this provider doesn't change when the console UI changes.
class RunnerProvider extends ChangeNotifier {
  final DartRunnerService _service;
  final List<ConsoleEvent> _events = [];
  StreamSubscription<ConsoleEvent>? _subscription;
  bool _isRunning = false;

  RunnerProvider({DartRunnerService? service}) : _service = service ?? DartRunnerService();

  List<ConsoleEvent> get events => List.unmodifiable(_events);
  bool get isRunning => _isRunning;

  /// [args] become `main`'s `List<String> args` parameter (Section 34)
  /// — real support, since `tom_d4rt`'s `execute()` takes
  /// `positionalArgs` directly (verified in Phase 3 before this was
  /// wired up).
  Future<void> run(String source, {List<String> args = const []}) async {
    await _subscription?.cancel();
    _events.clear();
    _isRunning = true;
    notifyListeners();

    _subscription = _service.run(source, args: args).listen(
      (event) {
        _events.add(event);
        if (event.type == ConsoleEventType.exitCode) {
          _isRunning = false;
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

  /// Clears the output history (Console's Clear action). Doesn't touch
  /// a currently-running execution — events from that run will keep
  /// arriving and simply start the list over.
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
