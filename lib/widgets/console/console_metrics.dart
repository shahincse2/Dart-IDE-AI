import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../utils/constants.dart';
import 'console_output_row.dart';

/// Measurements of the console font that the row layout depends on.
class ConsoleMetrics {
  const ConsoleMetrics._(this.widestGlyph, this.labelWidth);

  /// Width of the widest plain-ASCII glyph. A short ASCII line can never be
  /// wider than "length x widest glyph", so it needs no further measuring.
  final double widestGlyph;

  /// Width of the label column of `stderr` rows.
  final double labelWidth;

  /// Measures the current console fonts (do this once and keep the result).
  static ConsoleMetrics measure() {
    final style = consoleTextStyle();
    final glyph =
        ['M', 'W', '@', '%'].map((g) => _widthOf(g, style)).reduce(math.max);
    final label =
        _widthOf('stderr', consoleLabelStyle()) + AppConstants.spaceSm;
    return ConsoleMetrics._(glyph, label);
  }

  static double _widthOf(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
