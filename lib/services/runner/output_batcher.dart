import 'dart:async';
import 'dart:isolate';

import 'runner_limits.dart';
import 'runner_messages.dart';

/// Isolate-side: sends output lines to the main isolate in batches
/// (<= [_flushLines] lines or [_flushEvery] apart) instead of one message
/// per line, and enforces [kMaxOutputLines].
///
/// A synchronous flood (`while (true) print(...)`) never lets a Timer fire,
/// so [add] itself checks the line count and the clock. The periodic Timer
/// only matters for async programs that print slowly and then wait.
class OutputBatcher {
  OutputBatcher(this._port) {
    _timer = Timer.periodic(_flushEvery, (_) => flush());
  }

  static const int _flushLines = 100;
  static const Duration _flushEvery = Duration(milliseconds: 50);

  final SendPort _port;
  final List<String> _buffer = [];
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _timer;
  int _total = 0;
  bool _limitHit = false;

  /// Counts one line against the cap; false once the cap is reached.
  bool _accept() {
    if (_limitHit) return false;
    if (_total >= kMaxOutputLines) {
      _limitHit = true;
      flush();
      _port.send(const RunnerMessage.limit());
      return false;
    }
    _total++;
    return true;
  }

  void add(String line) {
    if (!_accept()) return;
    _buffer.add(line);
    if (_buffer.length >= _flushLines || _clock.elapsed >= _flushEvery) {
      flush();
    }
  }

  /// An stderr line. Goes out immediately, after any pending stdout, so the
  /// order the program wrote things in is kept.
  void addError(String line) {
    if (!_accept()) return;
    flush();
    _port.send(RunnerMessage.stderr(line));
  }

  void flush() {
    if (_buffer.isNotEmpty) {
      _port.send(RunnerMessage.stdoutBatch(List<String>.of(_buffer)));
      _buffer.clear();
    }
    _clock.reset();
  }

  /// Sends what is left and stops the timer (so the isolate can exit).
  void dispose() {
    _timer?.cancel();
    _timer = null;
    flush();
  }
}
