import 'dart:async';

import 'package:flutter/material.dart';

import '../models/console_event.dart';
import '../services/dart_runner_service.dart';
import '../services/eval_service.dart';

class RunnerProvider extends ChangeNotifier {
  final DartRunnerService _service;
  final EvalService evalService;
  final List<ConsoleEvent> _events = [];
  StreamSubscription<ConsoleEvent>? _subscription;
  StreamSubscription<void>? _stdinSubscription;
  bool _isRunning = false;
  bool _waitingForStdin = false;

  String _lastSource = '';
  List<String> _lastArgs = const [];

  RunnerProvider({DartRunnerService? service, EvalService? evalService})
      : _service = service ?? DartRunnerService(),
        evalService = evalService ?? EvalService() {
    _stdinSubscription = _service.stdinRequests.listen((_) {
      _waitingForStdin = true;
      notifyListeners();
    });
  }

  List<ConsoleEvent> get events => List.unmodifiable(_events);
  bool get isRunning => _isRunning;
  bool get waitingForStdin => _waitingForStdin;

  Future<void> run(String source, {List<String> args = const []}) async {
    await _subscription?.cancel();
    _events.clear();
    _isRunning = true;
    _waitingForStdin = false;
    _lastSource = source;
    _lastArgs = args;
    evalService.clearSession();
    notifyListeners();

    _subscription = _service.run(source, args: args).listen(
          (event) {
        _events.add(event);
        if (event.type == ConsoleEventType.exitCode) {
          _isRunning = false;
          _waitingForStdin = false;
          if (event.exitCode == 0) {
            unawaited(evalService.setupSession(_lastSource, args: _lastArgs));
          }
        }
        notifyListeners();
      },
      onDone: () {
        _isRunning = false;
        _waitingForStdin = false;
        notifyListeners();
      },
    );
  }

  void submitStdinInput(String text) {
    if (!_waitingForStdin) return;
    _events.add(ConsoleEvent.stdout(text));
    _waitingForStdin = false;
    notifyListeners();
    _service.sendStdinReply(text);
  }

  void stop() {
    _waitingForStdin = false;
    _service.stop();
  }

  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _stdinSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}