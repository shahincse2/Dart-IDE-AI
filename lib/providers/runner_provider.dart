import 'dart:async';

import 'package:flutter/material.dart';

import '../models/console_event.dart';
import '../services/dart_runner_service.dart';

/// Execution state for the currently open file. The real Console
/// panel (Phase 4) will read [events] the same way the temporary
/// output list in EditorScreen does now — this provider doesn't
/// change when the console UI is built.
class RunnerProvider extends ChangeNotifier {
  final DartRunnerService _service;
  final List<ConsoleEvent> _events = [];
  StreamSubscription<ConsoleEvent>? _subscription;
  bool _isRunning = false;

  RunnerProvider({DartRunnerService? service}) : _service = service ?? DartRunnerService();

  List<ConsoleEvent> get events => List.unmodifiable(_events);
  bool get isRunning => _isRunning;

  Future<void> run(String source) async {
    await _subscription?.cancel();
    _events.clear();
    _isRunning = true;
    notifyListeners();

    _subscription = _service.run(source).listen(
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
