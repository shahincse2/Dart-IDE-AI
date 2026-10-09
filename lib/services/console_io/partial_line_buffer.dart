/// Collects text written in arbitrary pieces and hands out complete lines.
///
/// `stdout.write('Name: ')` is not a line yet, `print('x')` is. Both go
/// through here, so output keeps its terminal-like order and a prompt only
/// becomes a line once something finishes it or [flush] is called.
class PartialLineBuffer {
  PartialLineBuffer(this._onLine);

  /// A line without a newline is cut after this many characters, so a loop
  /// of `stdout.write('x')` cannot grow the buffer forever.
  static const int _maxPending = 10000;

  final void Function(String line) _onLine;
  final StringBuffer _pending = StringBuffer();

  void write(String text) {
    if (text.isEmpty) return;
    if (!text.contains('\n')) {
      _pending.write(text);
      if (_pending.length >= _maxPending) flush();
      return;
    }
    final parts = (_pending.toString() + text).split('\n');
    _pending.clear();
    for (var i = 0; i < parts.length - 1; i++) {
      _onLine(_withoutCarriageReturn(parts[i]));
    }
    _pending.write(parts.last);
  }

  /// Emits the unfinished line, if there is one.
  void flush() {
    if (_pending.isEmpty) return;
    _onLine(_pending.toString());
    _pending.clear();
  }

  String _withoutCarriageReturn(String line) =>
      line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
}
