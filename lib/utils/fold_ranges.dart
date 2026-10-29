import 'dart_syntax_highlighter.dart';
import 'fold_regions.dart';

/// The string and comment ranges of [tokens] (start, end, start, end ...):
/// brackets inside them do not open a fold.
List<int> foldSkipRanges(List<SyntaxToken> tokens) {
  final out = <int>[];
  for (final t in tokens) {
    if (t.type == TokenType.string || t.type == TokenType.comment) {
      out
        ..add(t.start)
        ..add(t.end);
    }
  }
  return out;
}

/// The lines hidden by the folded [regions] (sorted by start line): merged,
/// sorted, inclusive ranges. A region hides the lines between its first and
/// last line.
List<LineRange> mergeHiddenLines(List<FoldRegion> regions) {
  final merged = <LineRange>[];
  for (final r in regions) {
    final first = r.startLine + 1;
    final last = r.endLine - 1;
    if (merged.isNotEmpty && first <= merged.last.last + 1) {
      // Nested inside (or touching) an already-hidden range.
      if (last > merged.last.last) {
        merged[merged.length - 1] = LineRange(merged.last.first, last);
      }
    } else {
      merged.add(LineRange(first, last));
    }
  }
  return merged;
}

/// The same hidden lines as character offsets of a text of [textLength]
/// characters whose lines start at [lineStarts].
List<CharRange> hiddenCharRanges(
  List<LineRange> lines,
  List<int> lineStarts,
  int textLength,
) {
  return [
    for (final r in lines)
      CharRange(
        lineStarts[r.first],
        r.last + 1 < lineStarts.length ? lineStarts[r.last + 1] : textLength,
      ),
  ];
}
