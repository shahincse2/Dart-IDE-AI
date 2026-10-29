import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../code_editor_controller.dart';
import 'line_layout.dart';

/// Scrolls [scroll] just enough that the line the cursor is on is visible.
void scrollCursorIntoView({
  required CodeEditorController controller,
  required ScrollController scroll,
  required LineLayout layout,
  required bool wordWrap,
  required double lineHeight,
}) {
  if (!scroll.hasClients) return;
  final selection = controller.selection;
  if (!selection.isValid) return;

  final text = controller.text;
  final offset = selection.baseOffset.clamp(0, text.length).toInt();
  final before = text.substring(0, offset);
  final lineIndex = '\n'.allMatches(before).length;
  final lineStart = before.lastIndexOf('\n') + 1;

  if (lineIndex >= layout.lineTops.length - 1) return;

  // With word wrap, the caret may sit on a later visual row of its logical
  // line — find which one.
  var rowInLine = 0;
  final style = layout.measurer.style;
  if (wordWrap && style != null && offset > lineStart) {
    var lineEnd = text.indexOf('\n', offset);
    if (lineEnd == -1) lineEnd = text.length;
    final tp = TextPainter(
      text: TextSpan(text: text.substring(lineStart, lineEnd), style: style),
      strutStyle: layout.measurer.strut,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: layout.measurer.wrapWidth);
    final dy = tp
        .getOffsetForCaret(TextPosition(offset: offset - lineStart), Rect.zero)
        .dy;
    tp.dispose();
    rowInLine = (dy / lineHeight).floor();
  }

  final lineTop = layout.lineTops[lineIndex] + rowInLine * lineHeight;
  final lineBottom = lineTop + lineHeight;

  final viewTop = scroll.offset;
  final viewportHeight = scroll.position.viewportDimension;
  final viewBottom = viewTop + viewportHeight;

  if (lineTop < viewTop) {
    scroll.animateTo(lineTop,
        duration: AppConstants.animFast, curve: Curves.easeOut);
  } else if (lineBottom > viewBottom) {
    scroll.animateTo(
      lineBottom - viewportHeight,
      duration: AppConstants.animFast,
      curve: Curves.easeOut,
    );
  }
}
