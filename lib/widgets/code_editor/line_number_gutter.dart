import 'package:flutter/material.dart';

import '../../utils/fold_regions.dart';
import '../../utils/themes.dart';
import 'gutter_row.dart';

/// The line-number column: a number (and, on foldable lines, a chevron) at the
/// top of each line, kept in lockstep with the text by [lineTops] and
/// [scrollOffset]. Only lines near the visible viewport are built.
class LineNumberGutter extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final double fontSize;
  final double width;
  final double chevronWidth;
  final List<double> lineTops;
  final List<LineRange> hiddenLines;
  final int currentLine;
  final double scrollOffset;
  final double? viewportHeight;
  final Map<int, FoldRegion> regionByStart;
  final bool Function(int line) isFolded;
  final void Function(int line) onToggleFold;

  const LineNumberGutter({
    super.key,
    required this.scheme,
    required this.lineHeight,
    required this.fontSize,
    required this.width,
    required this.chevronWidth,
    required this.lineTops,
    required this.hiddenLines,
    required this.currentLine,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.regionByStart,
    required this.isFolded,
    required this.onToggleFold,
  });

  /// Largest line index whose top is <= [y].
  int _lineAtY(double y, int lineCount) {
    var lo = 0;
    var hi = lineCount - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lineTops[mid] <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  @override
  Widget build(BuildContext context) {
    final lineCount = lineTops.length - 1;

    // Only lines near the visible viewport are built.
    int firstVisible;
    int lastVisible;
    final viewport = viewportHeight;
    if (viewport == null) {
      // No layout measurement yet (first frame) — render everything once.
      firstVisible = 0;
      lastVisible = lineCount - 1;
    } else {
      const buffer = 4; // extra lines so fast flings don't show a blank edge
      firstVisible =
          (_lineAtY(scrollOffset, lineCount) - buffer).clamp(0, lineCount - 1);
      lastVisible = (_lineAtY(scrollOffset + viewport, lineCount) + buffer)
          .clamp(0, lineCount - 1);
    }

    final children = <Widget>[];
    var hr = 0; // pointer into hiddenLines (sorted)
    while (hr < hiddenLines.length && hiddenLines[hr].last < firstVisible) {
      hr++;
    }
    for (var i = firstVisible; i <= lastVisible; i++) {
      while (hr < hiddenLines.length && hiddenLines[hr].last < i) {
        hr++;
      }
      if (hr < hiddenLines.length && hiddenLines[hr].first <= i) {
        continue; // hidden by a fold: no number
      }

      children.add(
        Positioned(
          // The number sits on the FIRST visual row of its line, so wrapped
          // continuation rows get no number.
          top: lineTops[i] - scrollOffset + 1,
          left: 0,
          right: 0,
          height: lineHeight,
          child: GutterRow(
            line: i,
            scheme: scheme,
            fontSize: fontSize,
            chevronWidth: chevronWidth,
            isCurrent: i == currentLine,
            foldable: regionByStart.containsKey(i),
            folded: isFolded(i),
            onToggleFold: onToggleFold,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: scheme.gutterBackground,
        child: Stack(children: children),
      ),
    );
  }
}
