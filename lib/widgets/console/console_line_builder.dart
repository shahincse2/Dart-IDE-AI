import '../../models/console_event.dart';
import 'console_line.dart';

/// A single line longer than this is cut off (with an ellipsis).
const int kMaxConsoleLineChars = 4000;

final RegExp _combiningMark = RegExp(r'\p{M}', unicode: true);

bool _isPlainAscii(String text) {
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c > 126 || c == 9) return false;
  }
  return true;
}

/// True if the character at [i] belongs to the one before it, so a row must
/// not end between them (surrogate pairs, combining marks, joiners, and the
/// virama of Bengali / Devanagari conjuncts).
bool _continuesCluster(String text, int i) {
  final c = text.codeUnitAt(i);
  if (c >= 0xDC00 && c <= 0xDFFF) return true;
  if (c == 0x200D || c == 0x200C) return true;
  if (_combiningMark.hasMatch(String.fromCharCode(c))) return true;
  final previous = text.codeUnitAt(i - 1);
  return previous == 0x200D || previous == 0x09CD || previous == 0x094D;
}

/// Splits one line of text into rows of at most [columns] characters.
///
/// Prefers to break at a space. Text with non-ASCII characters (whose glyphs
/// are usually wider than the monospace font's) gets shorter rows, and a
/// hard break never splits a character cluster.
List<String> wrapRow(String text, int columns) {
  final width = columns < 1 ? 1 : columns;
  final limit = _isPlainAscii(text) ? width : (width * 0.6).floor().clamp(1, width);
  if (text.length <= limit) return [text];

  final rows = <String>[];
  var start = 0;
  while (text.length - start > limit) {
    final space = text.lastIndexOf(' ', start + limit);
    if (space > start + limit ~/ 2) {
      rows.add(text.substring(start, space));
      start = space + 1;
      continue;
    }
    var end = start + limit;
    while (end > start + 1 && _continuesCluster(text, end)) {
      end--;
    }
    rows.add(text.substring(start, end));
    start = end;
  }
  rows.add(text.substring(start));
  return rows;
}

/// Turns the runner's events into fixed-height [ConsoleLine]s, remembering
/// how far it got so each update only handles the new events.
class ConsoleLineBuilder {
  final List<ConsoleLine> lines = [];
  int _columns = 0;
  int _consumed = 0;

  /// Brings [lines] up to date. Starts over when the console width
  /// ([columns]) changes or the events were cleared.
  void update(List<ConsoleEvent> events, {required int columns}) {
    if (columns != _columns || events.length < _consumed) {
      reset();
      _columns = columns;
    }
    for (var i = _consumed; i < events.length; i++) {
      _add(events[i]);
    }
    _consumed = events.length;
  }

  void reset() {
    lines.clear();
    _consumed = 0;
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
      for (final row in wrapRow(_tidy(piece), _columns)) {
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
