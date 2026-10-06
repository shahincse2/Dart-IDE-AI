/// Pure-Dart helpers for code folding (no Flutter imports).
///
/// A "fold region" is a pair of matching brackets — `{}`, `()` or `[]` —
/// whose opener sits on line S and whose closer sits on line E, with at
/// least one full line in between (E >= S + 2). Folding hides lines
/// S+1 .. E-1; the opener line and the closer line stay visible, which
/// also gives the nice `} else {` behaviour for free.
library;

/// One foldable region. Lines are 0-based.
class FoldRegion {
  /// Line holding the opening bracket (stays visible).
  final int startLine;

  /// Line holding the matching closing bracket (stays visible).
  final int endLine;

  const FoldRegion(this.startLine, this.endLine);

  int get hiddenLineCount => endLine - startLine - 1;
}

/// Inclusive range of line indexes.
class LineRange {
  final int first;
  final int last;
  const LineRange(this.first, this.last);
}

/// Half-open range of character offsets: [start, end).
class CharRange {
  final int start;
  final int end;
  const CharRange(this.start, this.end);
}

/// Offset of the first character of every line (always starts with 0).
List<int> computeLineStarts(String text) {
  final starts = <int>[0];
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 10) starts.add(i + 1);
  }
  return starts;
}

class _Open {
  final int closer;
  final int line;
  const _Open(this.closer, this.line);
}

/// Finds every foldable region in [text].
///
/// [skipRanges] is a flat, source-ordered list `[start0, end0, start1,
/// end1, ...]` of character ranges to ignore (string and comment
/// tokens), so brackets inside them never count.
///
/// When several regions start on the same line (e.g. `foo(() {`), only
/// the one reaching furthest down is kept, so each line has at most one
/// fold chevron.
List<FoldRegion> computeFoldRegions(String text, List<int> skipRanges) {
  const closerFor = <int, int>{
    123: 125, // { }
    40: 41, // ( )
    91: 93, // [ ]
  };

  final stack = <_Open>[];
  final byStart = <int, FoldRegion>{};
  var line = 0;
  var skipIdx = 0;

  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);

    // Newlines are counted even inside multi-line strings/comments.
    if (c == 10) {
      line++;
      continue;
    }

    while (skipIdx < skipRanges.length && skipRanges[skipIdx + 1] <= i) {
      skipIdx += 2;
    }
    if (skipIdx < skipRanges.length && skipRanges[skipIdx] <= i) continue;

    final closer = closerFor[c];
    if (closer != null) {
      stack.add(_Open(closer, line));
      continue;
    }

    if (c == 125 || c == 41 || c == 93) {
      var k = stack.length - 1;
      while (k >= 0 && stack[k].closer != c) {
        k--;
      }
      if (k < 0) continue; // stray closer while the user is typing
      final open = stack[k];
      stack.removeRange(k, stack.length);

      if (line - open.line >= 2) {
        final existing = byStart[open.line];
        if (existing == null || line > existing.endLine) {
          byStart[open.line] = FoldRegion(open.line, line);
        }
      }
    }
  }

  final result = byStart.values.toList()
    ..sort((a, b) => a.startLine.compareTo(b.startLine));
  return result;
}
