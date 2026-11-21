import 'package:flutter/painting.dart' show TextSpan;

/// Remembers the last coloured text of an editor together with everything it
/// was built from. Asking again with the same [inputs] gives the very same
/// [TextSpan] without any work, and the text layout can see at once that
/// nothing changed.
///
/// The text field asks for its text on every rebuild, and the editor rebuilds
/// on every scroll tick; without this, scrolling a long file would colour the
/// whole file again for every frame.
class SpanCache {
  Object? _inputs;
  TextSpan? _span;

  /// The span for [inputs]: the remembered one if they are equal to the last
  /// inputs, else a new one made by [make] (and remembered).
  TextSpan build(Object inputs, TextSpan Function() make) {
    final span = _span;
    if (span != null && _inputs == inputs) return span;
    final fresh = make();
    _inputs = inputs;
    _span = fresh;
    return fresh;
  }
}
