import 'dart:async';
import 'dart:collection';

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

  /// Output events arrive far faster than the UI can usefully redraw
  /// (an infinite `print` loop can produce thousands per second), so
  /// stdout/stderr events only schedule ONE notification per window
  /// instead of one per event. State changes (exit, stdin) still notify
  /// immediately.
  static const Duration _notifyWindow = Duration(milliseconds: 50);
  Timer? _notifyTimer;

  RunnerProvider({DartRunnerService? service, EvalService? evalService})
      : _service = service ?? DartRunnerService(),
        evalService = evalService ?? EvalService() {
    _stdinSubscription = _service.stdinRequests.listen((_) {
      _waitingForStdin = true;
      notifyListeners();
    });
  }

  /// A live read-only VIEW of the event list. (It used to be
  /// `List.unmodifiable(_events)`, which COPIES the whole list on every
  /// access — and several listeners read it on every event, so a long
  /// run became quadratic and froze the UI.)
  List<ConsoleEvent> get events => UnmodifiableListView(_events);
  bool get isRunning => _isRunning;
  bool get waitingForStdin => _waitingForStdin;

  void _notifyThrottled() {
    if (_notifyTimer != null) return;
    _notifyTimer = Timer(_notifyWindow, () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  Future<void> run(String source, {List<String> args = const []}) async {
    await _subscription?.cancel();
    _notifyTimer?.cancel();
    _notifyTimer = null;
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
          _notifyTimer?.cancel();
          _notifyTimer = null;
          _isRunning = false;
          _waitingForStdin = false;
          if (event.exitCode == 0) {
            unawaited(evalService.setupSession(_lastSource, args: _lastArgs));
          }
          notifyListeners();
        } else {
          _notifyThrottled();
        }
      },
      onDone: () {
        _notifyTimer?.cancel();
        _notifyTimer = null;
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
    _notifyTimer?.cancel();
    _subscription?.cancel();
    _stdinSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
