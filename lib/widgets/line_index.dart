import 'package:flutter/widgets.dart';

/// How many lines a text controller's text has, and which line the cursor is
/// on. Both are worked out again only when the text (or the cursor) changes:
/// the editor asks on every rebuild, scrolling included.
mixin LineIndex on TextEditingController {
  String? _countedText;
  int _lineCount = 1;

  String? _locatedText;
  int _locatedOffset = -1;
  int _locatedLine = 0;

  /// The number of lines (a text with no line break has one).
  int get lineCount {
    final t = text;
    if (!identical(t, _countedText)) {
      _countedText = t;
      _lineCount = _newlinesIn(t, t.length) + 1;
    }
    return _lineCount;
  }

  /// The 0-based line the cursor is on, or -1 when there is no cursor.
  int get currentLine {
    final offset = selection.baseOffset;
    if (offset < 0) return -1;
    final t = text;
    if (identical(t, _locatedText) && offset == _locatedOffset) {
      return _locatedLine;
    }
    _locatedText = t;
    _locatedOffset = offset;
    _locatedLine = _newlinesIn(t, offset.clamp(0, t.length).toInt());
    return _locatedLine;
  }

  static int _newlinesIn(String text, int end) {
    var count = 0;
    for (var i = 0; i < end; i++) {
      if (text.codeUnitAt(i) == 10) count++;
    }
    return count;
  }
}
