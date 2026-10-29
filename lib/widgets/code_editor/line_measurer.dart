import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Measures lines of text in the editor's style: how many visual rows one
/// logical line takes at the wrapping width, and how wide it is. Results are
/// cached by line text, until [reset] is called with a new style or width.
class LineMeasurer {
  final Map<String, int> _rowsCache = {};
  final Map<String, double> _widthCache = {};

  TextStyle? style;
  StrutStyle? strut;
  double wrapWidth = 1;
  double _charWidth = 0;

  /// New style or width: forget everything measured and measure one
  /// character of the (monospace) style again.
  void reset({
    required TextStyle style,
    required StrutStyle strut,
    required double wrapWidth,
  }) {
    _rowsCache.clear();
    _widthCache.clear();
    this.style = style;
    this.strut = strut;
    this.wrapWidth = wrapWidth;
    _charWidth = _measureCharWidth();
  }

  /// Keeps the caches from growing without end while editing.
  void trim() {
    if (_rowsCache.length > 4000) _rowsCache.clear();
    if (_widthCache.length > 4000) _widthCache.clear();
  }

  double _measureCharWidth() {
    final tp = TextPainter(
      text: TextSpan(text: 'MMMMMMMMMM', style: style),
      strutStyle: strut,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final w = tp.width / 10;
    tp.dispose();
    return w;
  }

  static bool isPlainAscii(String s) {
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c > 126 || c == 9) return false;
    }
    return true;
  }

  /// How many visual rows one logical line occupies at the current wrapping
  /// width. Cached by line text.
  int rowsForLine(String line) {
    if (line.isEmpty) return 1;
    final cached = _rowsCache[line];
    if (cached != null) return cached;

    int rows;
    if (line.length * _charWidth <= wrapWidth && isPlainAscii(line)) {
      rows = 1; // certainly fits on one row, skip the TextPainter
    } else {
      final tp = TextPainter(
        text: TextSpan(text: line, style: style),
        strutStyle: strut,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: wrapWidth);
      rows = math.max(1, tp.computeLineMetrics().length);
      tp.dispose();
    }
    _rowsCache[line] = rows;
    return rows;
  }

  /// Natural (unwrapped) width of one line, cached by text. Plain-ASCII lines
  /// in a monospace font are exactly `length * charWidth` (the measured char
  /// width already includes the style's letterSpacing); anything else is
  /// measured with a TextPainter.
  double widthForLine(String line) {
    if (line.isEmpty) return 0;
    final cached = _widthCache[line];
    if (cached != null) return cached;

    final w = isPlainAscii(line) ? line.length * _charWidth : measureLineWidth(line);
    _widthCache[line] = w;
    return w;
  }

  /// Exact unwrapped width of one line (used for the fold chip, which only
  /// exists for a handful of lines, so measuring is cheap).
  double measureLineWidth(String line) {
    if (line.isEmpty) return 0;
    final tp = TextPainter(
      text: TextSpan(text: line, style: style),
      strutStyle: strut,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }
}
