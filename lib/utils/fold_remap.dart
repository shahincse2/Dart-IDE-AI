import 'dart:math' as math;

import 'fold_regions.dart';

int _newlinesIn(String s, int from, int to) {
  var n = 0;
  for (var i = from; i < to; i++) {
    if (s.codeUnitAt(i) == 10) n++;
  }
  return n;
}

/// Which of the [folded] start lines survive the edit from [oldText] to
/// [newText], and where they are afterwards: each one shifts by the number of
/// lines the edit added/removed above it, and a fold the edit touches is
/// dropped (unfolded). [regions] and [lineStarts] describe [oldText].
Set<int> remapFoldedStarts({
  required String oldText,
  required String newText,
  required List<FoldRegion> regions,
  required Set<int> folded,
  required List<int> lineStarts,
}) {
  // Smallest changed window: common prefix / suffix.
  final minLen = math.min(oldText.length, newText.length);
  var p = 0;
  while (p < minLen && oldText.codeUnitAt(p) == newText.codeUnitAt(p)) {
    p++;
  }
  var s = 0;
  while (s < minLen - p &&
      oldText.codeUnitAt(oldText.length - 1 - s) ==
          newText.codeUnitAt(newText.length - 1 - s)) {
    s++;
  }
  final oldEnd = oldText.length - s; // edit = [p, oldEnd) in old text
  final newEnd = newText.length - s;

  final editLine = _newlinesIn(oldText, 0, p);
  final removed = _newlinesIn(oldText, p, oldEnd);
  final added = _newlinesIn(newText, p, newEnd);
  final delta = added - removed;

  final survivors = <int>{};
  for (final r in regions) {
    if (!folded.contains(r.startLine)) continue;
    final f = r.startLine;

    // Edit touches this fold's hidden text -> unfold it.
    final hiddenStart = lineStarts[f + 1];
    final hiddenEnd = lineStarts[r.endLine];
    if (p < hiddenEnd && oldEnd > hiddenStart) continue;

    if (f < editLine) {
      survivors.add(f);
    } else if (f == editLine) {
      // Typing on the fold's own line keeps it folded; adding or removing
      // line breaks there changes what it covers.
      if (removed == 0 && added == 0) survivors.add(f);
    } else if (editLine + removed < f) {
      survivors.add(f + delta);
    }
    // else: the edit spans the start line -> unfold.
  }
  return survivors;
}
