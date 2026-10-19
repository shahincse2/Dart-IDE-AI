import 'dart:math' as math;

/// The least height at which the console's own parts (drag handle, header,
/// the input bar and at least a line of output) still fit. Below this the
/// layout overflows.
const double kConsoleMinUsableHeight = 150;

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
/// between the least that fits its own parts and [maxHeight].
///
/// The least is [minOpen] or [kConsoleMinUsableHeight], whichever is larger,
/// and it wins over a smaller [maxHeight]: a console too small for its own
/// header and input bar is worse than one that is a little too big.
double consoleHeightFor({
  required double wanted,
  required double minOpen,
  required double maxHeight,
}) {
  final floor = math.max(minOpen, kConsoleMinUsableHeight);
  if (maxHeight <= floor) return floor;
  return math.min(math.max(wanted, floor), maxHeight);
}
