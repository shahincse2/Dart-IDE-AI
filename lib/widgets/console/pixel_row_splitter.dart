import 'package:flutter/widgets.dart';

/// True if every character is plain ASCII (and not a tab).
bool isPlainAscii(String text) {
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c > 126 || c == 9) return false;
  }
  return true;
}

/// Cuts [text] into rows that fit [maxWidth] pixels, at exactly the places
/// Flutter's own text layout would wrap it: at spaces, and through a word
/// only when the word alone is wider than a row, never through a character.
///
/// Works for any font (monospace or not) and any script, because it asks
/// the text engine instead of counting characters.
List<String> splitByPixels(String text, TextStyle style, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: maxWidth);

  final rows = <String>[];
  var offset = 0;
  while (offset < text.length) {
    var end = painter.getLineBoundary(TextPosition(offset: offset)).end;
    if (end <= offset || end > text.length) end = text.length; // never stall
    rows.add(text.substring(offset, end).trimRight());
    offset = end;
  }
  painter.dispose();
  return rows.isEmpty ? [text] : rows;
}
