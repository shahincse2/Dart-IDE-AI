import 'dart:async';

/// The time limit of a run. It can be paused (while the program waits for
/// the user to type) and then starts afresh, so the limit counts running
/// time only.
class RunTimer {
  Timer? _timer;
  Duration _limit = Duration.zero;
  void Function()? _onTimeout;

  void start(Duration limit, void Function() onTimeout) {
    _limit = limit;
    _onTimeout = onTimeout;
    _arm();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Starts the full limit again (no-op if the timer was cancelled).
  void resume() {
    if (_onTimeout != null) _arm();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _onTimeout = null;
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(_limit, () => _onTimeout?.call());
  }
}
