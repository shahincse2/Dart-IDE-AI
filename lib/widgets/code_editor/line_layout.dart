import 'package:flutter/material.dart';

import '../../utils/fold_regions.dart';
import 'line_measurer.dart';

/// Where each logical line of the text sits: [lineTops] holds the y (px) of
/// the top of every line (and, last, the total content height), counting how
/// many visual rows a line takes (word wrap) and the folds (the first hidden
/// line of a fold owns its one placeholder row, the rest are 0px tall).
class LineLayout {
  final LineMeasurer measurer = LineMeasurer();

  /// `lineTops[i]` = y (px) of the top of logical line i; `lineTops.last` =
  /// total content height. Length = lineCount + 1.
  List<double> lineTops = const [0.0];
  List<String> lines = const [''];

  /// Natural width of the widest visible line (word wrap OFF only).
  double maxLineWidth = 0;

  String? _text;
  double _width = -1;
  double _fontSize = -1;
  bool _wrap = true;
  String _hiddenSig = '';
  TextStyle? _style;

  /// Whether [line] is inside one of the (sorted) hidden [ranges].
  static bool isLineHidden(int line, List<LineRange> ranges) {
    for (final r in ranges) {
      if (line >= r.first && line <= r.last) return true;
      if (r.first > line) break;
    }
    return false;
  }

  /// Rebuilds [lineTops] when the text, wrapping width, font size, wrap mode,
  /// style or fold state changed; otherwise returns immediately.
  void ensure({
    required String text,
    required double wrapWidth,
    required TextStyle style,
    required double fontSize,
    required double lineHeight,
    required StrutStyle strut,
    required bool wordWrap,
    required List<LineRange> hiddenLines,
    required String hiddenSig,
  }) {
    final measureUnchanged = _width == wrapWidth &&
        _fontSize == fontSize &&
        _wrap == wordWrap &&
        _style == style;
    if (measureUnchanged && _text == text && _hiddenSig == hiddenSig) return;

    if (!measureUnchanged) {
      measurer.reset(style: style, strut: strut, wrapWidth: wrapWidth);
    }
    measurer.trim();
    _width = wrapWidth;
    _fontSize = fontSize;
    _wrap = wordWrap;
    _style = style;
    _text = text;
    _hiddenSig = hiddenSig;

    final split = text.split('\n');
    final tops = List<double>.filled(split.length + 1, 0);
    var y = 0.0;
    var maxWidth = 0.0;
    var hr = 0; // pointer into hiddenLines (sorted)
    for (var i = 0; i < split.length; i++) {
      while (hr < hiddenLines.length && hiddenLines[hr].last < i) {
        hr++;
      }
      final hidden = hr < hiddenLines.length && hiddenLines[hr].first <= i;

      tops[i] = y;
      if (hidden) {
        // The first hidden line of a range owns the single placeholder row;
        // the rest of the range adds no height.
        if (i == hiddenLines[hr].first) y += lineHeight;
        continue;
      }
      if (wordWrap) {
        y += measurer.rowsForLine(split[i]) * lineHeight;
      } else {
        y += lineHeight;
        final w = measurer.widthForLine(split[i]);
        if (w > maxWidth) maxWidth = w;
      }
    }
    tops[split.length] = y;
    lines = split;
    lineTops = tops;
    maxLineWidth = maxWidth;
  }
}
