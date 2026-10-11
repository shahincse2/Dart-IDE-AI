import 'dart:async';

/// The UI side of "the program wants a line" / "the user typed a line".
///
/// The runner calls [requestLine] when the program starts waiting; the UI
/// listens to [requests], shows an input field, and answers with [reply],
/// which hands the line to whatever the runner [attach]ed.
class StdinBridge {
  final StreamController<void> _requests = StreamController<void>.broadcast();
  final StreamController<bool> _waiting = StreamController<bool>.broadcast();
  void Function(String line)? _deliver;
  bool _isWaiting = false;

  /// Fires each time the program starts waiting for input.
  Stream<void> get requests => _requests.stream;

  /// `true` when the program starts waiting for a line, `false` when the
  /// wait ends (answered, or the run ended).
  Stream<bool> get waitingChanges => _waiting.stream;

  bool get hasPending => _isWaiting;

  /// A run starts: answers go to [deliver].
  void attach(void Function(String line) deliver) {
    _deliver = deliver;
    _isWaiting = false;
  }

  /// The run is over. A wait that is still open just ends, unanswered.
  void detach() {
    _deliver = null;
    _endWait();
  }

  /// The running program asks for a line.
  void requestLine() {
    _isWaiting = true;
    _requests.add(null);
    _waiting.add(true);
  }

  /// The user's answer. Ignored when nothing is waiting.
  void reply(String text) {
    if (!_isWaiting) return;
    _deliver?.call(text);
    _endWait();
  }

  void _endWait() {
    if (!_isWaiting) return;
    _isWaiting = false;
    _waiting.add(false);
  }

  void dispose() {
    _requests.close();
    _waiting.close();
  }
}
