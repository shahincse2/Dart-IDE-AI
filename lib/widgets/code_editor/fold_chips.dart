import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/fold_regions.dart';
import '../../utils/themes.dart';
import '../code_editor_controller.dart';
import 'fold_chip.dart';
import 'line_layout.dart';

/// One "..." chip per folded block, on its placeholder row (the first hidden
/// line), indented like the folded code.
List<Widget> buildFoldChips({
  required CodeEditorController controller,
  required EditorColorScheme scheme,
  required LineLayout layout,
  required Map<int, FoldRegion> regionByStart,
  required List<LineRange> hiddenLines,
  required double lineHeight,
  required double scrollOffset,
}) {
  final lineTops = layout.lineTops;
  final lines = layout.lines;
  final chips = <Widget>[];
  for (final s in controller.foldedStartLines) {
    final region = regionByStart[s];
    if (region == null) continue;
    if (LineLayout.isLineHidden(s, hiddenLines)) {
      continue; // inside an outer fold
    }
    final p = s + 1; // placeholder row = first hidden line
    if (p + 1 >= lineTops.length || p >= lines.length) continue;

    var indent = '';
    for (var l = p; l < region.endLine && l < lines.length; l++) {
      final t = lines[l];
      if (t.trim().isEmpty) continue;
      indent = t.substring(0, t.length - t.trimLeft().length);
      break;
    }
    final x = indent.isEmpty
        ? 0.0
        : layout.measurer.measureLineWidth('${indent}x') -
            layout.measurer.measureLineWidth('x');

    chips.add(
      Positioned(
        left: AppConstants.spaceSm + x,
        top: lineTops[p] - scrollOffset,
        height: lineHeight,
        child: FoldChip(
          scheme: scheme,
          lineHeight: lineHeight,
          onTap: () => controller.toggleFold(s),
        ),
      ),
    );
  }
  return chips;
}
