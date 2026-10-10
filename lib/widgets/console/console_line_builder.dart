import '../../models/console_event.dart';
import 'console_line.dart';

/// A single line longer than this is cut off (with an ellipsis).
const int kMaxConsoleLineChars = 4000;

/// How one line of text is cut into rows. Supplied by the widget, because
/// the answer depends on the font, the screen width, and whether the row
/// carries the `stderr` label.
typedef RowSplitter = List<String> Function(String text, ConsoleEventType type);

/// Turns the runner's events into fixed-height [ConsoleLine]s, remembering
/// how far it got so each update only handles the new events.
class ConsoleLineBuilder {
  final List<ConsoleLine> lines = [];
  int _layoutKey = -1;
  RowSplitter _splitter = (text, type) => [text];
  int _consumed = 0;
  ConsoleEvent? _firstEvent;

  /// Sets how rows are cut. [layoutKey] identifies the layout (for example
  /// the width in pixels); when it changes, everything is wrapped again.
  void configure({required int layoutKey, required RowSplitter splitter}) {
    if (layoutKey == _layoutKey) return;
    _layoutKey = layoutKey;
    _splitter = splitter;
    reset();
  }

  /// Brings [lines] up to date with [events].
  void update(List<ConsoleEvent> events) {
    // A new run, or a cleared console, must start over even if it already
    // has as many events as the old list had.
    final startedOver = events.length < _consumed ||
        (events.isNotEmpty && !identical(events.first, _firstEvent));
    if (startedOver) reset();

    _firstEvent = events.isEmpty ? null : events.first;
    for (var i = _consumed; i < events.length; i++) {
      _add(events[i]);
    }
    _consumed = events.length;
  }

  void reset() {
    lines.clear();
    _consumed = 0;
    _firstEvent = null;
  }

  void _add(ConsoleEvent event) {
    if (event.type == ConsoleEventType.exitCode) {
      lines.add(ConsoleLine(
        type: event.type,
        text: 'Program finished (exit code ${event.exitCode})',
        isFirst: true,
        exitCode: event.exitCode,
      ));
      return;
    }
    var first = true;
    for (final piece in (event.text ?? '').split('\n')) {
      for (final row in _splitter(_tidy(piece), event.type)) {
        lines.add(ConsoleLine(type: event.type, text: row, isFirst: first));
        first = false;
      }
    }
  }

  String _tidy(String piece) {
    var text = piece.endsWith('\r') ? piece.substring(0, piece.length - 1) : piece;
    text = text.replaceAll('\t', '    ');
    return text.length > kMaxConsoleLineChars
        ? '${text.substring(0, kMaxConsoleLineChars)}…'
        : text;
  }
}
