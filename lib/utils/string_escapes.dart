/// Where the escape sequences (`\n`, `\t`, `\u00e9`, `\$` ...) sit inside
/// string literals, so the editor can colour them differently from the
/// rest of the string.
class EscapeRanges {
  const EscapeRanges(this._starts, this._ends);

  static const EscapeRanges empty = EscapeRanges([], []);

  final List<int> _starts; // sorted, no overlaps
  final List<int> _ends;

  /// Every start and end offset: the places a highlighted span must be split.
  Iterable<int> get boundaries sync* {
    for (var i = 0; i < _starts.length; i++) {
      yield _starts[i];
      yield _ends[i];
    }
  }

  /// True if [start, end) lies inside a single escape sequence.
  bool covers(int start, int end) {
    var low = 0;
    var high = _starts.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_starts[mid] <= start) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found >= 0 && end <= _ends[found];
  }
}

final RegExp _escape = RegExp(
  r'\\(?:u\{[0-9A-Fa-f]{1,6}\}|u[0-9A-Fa-f]{4}|x[0-9A-Fa-f]{2}|[\s\S])',
);
final RegExp _identifierChar = RegExp(r'[A-Za-z0-9_$]');

/// Finds the escape sequences inside the string literals of [text].
///
/// [stringRanges] is flat, `[start0, end0, start1, end1, ...]`: the character
/// ranges of the string tokens. Raw strings (`r'...'`) have no escapes, so
/// they are skipped.
EscapeRanges findStringEscapes(String text, List<int> stringRanges) {
  final found = <List<int>>[];
  for (var i = 0; i + 1 < stringRanges.length; i += 2) {
    final from = stringRanges[i];
    final to = stringRanges[i + 1];
    if (from < 0 || to <= from || to > text.length) continue;
    if (_isRaw(text, from)) continue;
    for (final match in _escape.allMatches(text.substring(from, to))) {
      found.add([from + match.start, from + match.end]);
    }
  }

  found.sort((a, b) => a[0].compareTo(b[0]));
  final starts = <int>[];
  final ends = <int>[];
  for (final range in found) {
    if (ends.isNotEmpty && range[0] < ends.last) continue; // overlap
    starts.add(range[0]);
    ends.add(range[1]);
  }
  return EscapeRanges(starts, ends);
}

/// A string token may start at the `r` prefix or just after it.
bool _isRaw(String text, int start) {
  if (start + 1 < text.length &&
      text[start] == 'r' &&
      (text[start + 1] == "'" || text[start + 1] == '"')) {
    return true;
  }
  if (start > 0 && text[start - 1] == 'r') {
    final before = start > 1 ? text[start - 2] : ' ';
    return !_identifierChar.hasMatch(before);
  }
  return false;
}
