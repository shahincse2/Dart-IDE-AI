import 'package:flutter/widgets.dart';

/// How far [controller] is scrolled: 0 until it has a position.
///
/// When word wrap is switched on or off, the old and the new text field are
/// attached to the same controller for a moment, and `controller.offset`
/// throws while there is more than one position. The newest one is the one
/// that counts.
double scrollOffsetOf(ScrollController controller) {
  final positions = controller.positions;
  return positions.isEmpty ? 0.0 : positions.last.pixels;
}
