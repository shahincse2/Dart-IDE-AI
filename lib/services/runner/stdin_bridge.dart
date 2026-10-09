import 'dart:async';

/// Connects "the program wants a line" to "the user typed a line".
///
/// The interpreter calls [readLine] and waits; the UI listens to
/// [requests], shows an input field, and answers with [reply].
class StdinBridge {
  final StreamController<void> _requests = StreamController<void>.broadcast();
  Completer<String>? _pending;
  bool _cancelled = false;

  /// Fires each time the program starts waiting for input.
  Stream<void> get requests => _requests.stream;

  bool get hasPending => _pending != null && !_pending!.isCompleted;

  bool get isCancelled => _cancelled;

  /// Call before a new run.
  void reset() {
    _cancelled = false;
    _pending = null;
  }

  /// Called by the interpreter. Completes when the user submits a line.
  Future<String> readLine() async {
    if (_cancelled) return '';
    final completer = Completer<String>();
    _pending = completer;
    _requests.add(null);
    try {
      return await completer.future;
    } finally {
      if (identical(_pending, completer)) _pending = null;
    }
  }

  /// The user's answer.
  void reply(String text) {
    final completer = _pending;
    _pending = null;
    if (completer != null && !completer.isCompleted) completer.complete(text);
  }

  /// Ends the run: unblocks a waiting read and refuses new ones.
  void cancel() {
    _cancelled = true;
    reply('');
  }

  void dispose() => _requests.close();
}
