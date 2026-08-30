import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/console_event.dart';
import '../services/console_export_service.dart';
import '../utils/constants.dart';
import 'runner_provider.dart';

/// Console visibility and sizing (Section 26-29): hidden by default,
/// opens automatically when a run starts or when an error appears,
/// stays closed otherwise, and remembers a user-adjusted height.
///
/// Deliberately doesn't own the output events themselves — those stay
/// on [RunnerProvider], which already had them from Phase 3. This
/// provider is bound to a RunnerProvider instance (see `bind`) and
/// listens to it purely to decide when to open, rather than
/// duplicating the event list.
class ConsoleProvider extends ChangeNotifier {
  bool _isOpen = false;
  double _height = AppConstants.consoleDefaultHeight;

  RunnerProvider? _runner;
  int _lastSeenEventCount = 0;
  bool _wasRunning = false;

  bool get isOpen => _isOpen;
  double get height => _height;

  /// Wires this provider to the app's RunnerProvider instance. Safe to
  /// call on every rebuild (e.g. from a ChangeNotifierProxyProvider
  /// update callback) — re-binding to the same instance is a no-op.
  void bind(RunnerProvider runner) {
    if (identical(_runner, runner)) return;
    _runner?.removeListener(_onRunnerChanged);
    _runner = runner;
    _lastSeenEventCount = runner.events.length;
    _wasRunning = runner.isRunning;
    runner.addListener(_onRunnerChanged);
  }

  void _onRunnerChanged() {
    final runner = _runner;
    if (runner == null) return;

    final justStarted = runner.isRunning && !_wasRunning;
    final newEvents = runner.events.length > _lastSeenEventCount
        ? runner.events.sublist(_lastSeenEventCount)
        : const <ConsoleEvent>[];
    final hasNewError = newEvents.any((e) => e.type == ConsoleEventType.stderr);

    _wasRunning = runner.isRunning;
    _lastSeenEventCount = runner.events.length;

    if ((justStarted || hasNewError) && !_isOpen) {
      open();
    }
  }

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  void toggle() => _isOpen ? close() : open();

  /// Clamped by the caller (ConsolePanel knows the actual screen
  /// height available); this just guards against a degenerate value.
  void setHeight(double value, {required double maxHeight}) {
    _height = value.clamp(AppConstants.consoleMinOpenHeight, maxHeight);
    notifyListeners();
  }

  void clear() => _runner?.clearEvents();

  Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _formattedOutput()));
  }

  Future<String> saveToFile() => ConsoleExportService.saveAsText(_formattedOutput());

  String _formattedOutput() {
    final runner = _runner;
    if (runner == null) return '';
    final buffer = StringBuffer();
    for (final e in runner.events) {
      switch (e.type) {
        case ConsoleEventType.stdout:
        case ConsoleEventType.systemInfo:
          buffer.writeln(e.text ?? '');
        case ConsoleEventType.stderr:
          buffer.writeln('[stderr] ${e.text ?? ''}');
        case ConsoleEventType.exitCode:
          buffer.writeln('Program finished (exit code ${e.exitCode})');
      }
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _runner?.removeListener(_onRunnerChanged);
    super.dispose();
  }
}
