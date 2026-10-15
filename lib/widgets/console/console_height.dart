import 'dart:math' as math;

/// The tallest the console may be right now.
///
/// With the keyboard up, much of the screen is gone, so the console gets a
/// smaller share. Otherwise it pushes the editor out and the layout
/// overflows (for example while a "New file" dialog has the keyboard open).
double consoleMaxHeight({
  required double screenHeight,
  required double keyboardHeight,
}) {
  final visible = math.max(0.0, screenHeight - keyboardHeight);
  return visible * (keyboardHeight > 0 ? 0.35 : 0.7);
}

/// The height to draw the console at: what the user chose ([wanted]), kept
/// between [minOpen] and [maxHeight]. When [maxHeight] is smaller than
/// [minOpen] it wins, so the console never takes more room than there is.
double consoleHeightFor({
  required double wanted,
  required double minOpen,
  required double maxHeight,
}) {
  if (maxHeight <= minOpen) return maxHeight;
  return math.min(math.max(wanted, minOpen), maxHeight);
}
