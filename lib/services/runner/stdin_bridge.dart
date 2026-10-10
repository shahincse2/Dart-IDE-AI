import 'dart:async';

/// Connects "the program wants a line" to "the user typed a line".
///
/// The interpreter calls [readLine] and waits; the UI listens to
/// [requests], shows an input field, and answers with [reply].
class StdinBridge {
  final StreamController<void> _requests = StreamController<void>.broadcast();
  final StreamController<bool> _waiting = StreamController<bool>.broadcast();
  Completer<String>? _pending;
  bool _cancelled = false;

  /// Fires each time the program starts waiting for input.
  Stream<void> get requests => _requests.stream;

  /// `true` when the program starts waiting for a line, `false` when the
  /// wait ends (answered, or the run was cancelled).
  Stream<bool> get waitingChanges => _waiting.stream;

  bool get hasPending => _pending != null && !_pending!.isCompleted;

  bool get isCancelled => _cancelled;

  /// Call before a new run.
  void reset() {
    _cancelled = false;
    _pending = null;
  }

  /// Called by the interpreter. Completes when the user submits a line.
  Future<String> readLine() {
    // After Stop / the time limit the program is never answered again: it
    // stays suspended at this call. (Feeding it empty lines made a program
    // like `while (true) { await stdin.readLineSync(); }` spin forever on
    // the event queue, and that froze the whole app.)
    if (_cancelled) return Completer<String>().future;

    final completer = Completer<String>();
    _pending = completer;
    _requests.add(null);
    _waiting.add(true);
    return completer.future;
  }

  /// The user's answer.
  void reply(String text) {
    final completer = _pending;
    _pending = null;
    if (completer == null || completer.isCompleted) return;
    completer.complete(text);
    _waiting.add(false);
  }

  /// Ends the run. A read that is waiting right now is simply never
  /// answered, so the program stays suspended instead of carrying on.
  void cancel() {
    _cancelled = true;
    if (_pending == null) return;
    _pending = null;
    _waiting.add(false);
  }

  void dispose() {
    _requests.close();
    _waiting.close();
  }
}
