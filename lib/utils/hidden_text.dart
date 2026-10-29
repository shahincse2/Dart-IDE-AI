import 'package:flutter/material.dart';

import 'fold_regions.dart';

/// Font size of hidden text — tiny, so the hidden glyphs add practically no
/// width to the line they are merged into.
const double kHiddenFontSize = 0.001;

/// What is DRAWN for (a piece of) a hidden range. Same length as the real
/// text, so caret/selection offsets still line up: every '\n' becomes one
/// zero-width space — except the final '\n' of the range ([endsRange]), which
/// stays a real line break. So a folded block renders as exactly ONE row (the
/// "..." placeholder row, drawn by the editor) between the opening line and
/// the closing line.
String hiddenText(String s, {required bool endsRange}) {
  final z = s.replaceAll('\n', '\u200B');
  if (!endsRange || z.isEmpty || !s.endsWith('\n')) return z;
  return '${z.substring(0, z.length - 1)}\n';
}

/// Style for folded (hidden) text: tiny and transparent.
TextStyle hiddenStyle(TextStyle? base) {
  return (base ?? const TextStyle()).copyWith(
    fontSize: kHiddenFontSize,
    height: 1.0,
    letterSpacing: 0,
    wordSpacing: 0,
    fontWeight: FontWeight.normal,
    color: Colors.transparent,
    backgroundColor: Colors.transparent,
    decoration: TextDecoration.none,
  );
}

/// The hidden range that fully contains `[start, end)`, if any.
CharRange? hiddenRangeCovering(List<CharRange> hidden, int start, int end) {
  for (final r in hidden) {
    if (r.start <= start && end <= r.end) return r;
  }
  return null;
}

/// Plain rendering used while an IME is composing (accented characters, some
/// Asian-language input): the composing-region underline behaves correctly
/// only without split spans. Folded text is still kept hidden.
TextSpan buildComposingSpan({
  required String text,
  required TextStyle? style,
  required List<CharRange> hidden,
}) {
  if (hidden.isEmpty) return TextSpan(style: style, text: text);
  final plain = <TextSpan>[];
  var pos = 0;
  for (final r in hidden) {
    if (r.start > pos) {
      plain.add(TextSpan(text: text.substring(pos, r.start), style: style));
    }
    plain.add(
      TextSpan(
        text: hiddenText(text.substring(r.start, r.end), endsRange: true),
        style: hiddenStyle(style),
      ),
    );
    pos = r.end;
  }
  if (pos < text.length) {
    plain.add(TextSpan(text: text.substring(pos), style: style));
  }
  return TextSpan(style: style, children: plain);
}
