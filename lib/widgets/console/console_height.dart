import 'dart:math' as math;

/// The least height at which the console's input bar (shown while a program
/// waits for a line), its header and drag handle all still fit.
const double kConsoleInputBarMinHeight = 150;

/// The tallest the console may be right now.
///
/// At most 70% of the screen. When the screen knows how much room is left for
/// the console ([roomHeight]: what the screen's body has, minus its other
/// parts and a usable editor), the console takes no more than that. This
/// holds with the keyboard up too, because the body is already smaller then.
double consoleMaxHeight({
  required double screenHeight,
  double? roomHeight,
}) {
  final overall = screenHeight * 0.7;
  if (roomHeight == null) return overall;
  return math.min(overall, math.max(0.0, roomHeight));
}

/// The height to draw the console at: what the user chose ([wanted]), kept
/// between the least that fits and [maxHeight].
///
/// The least is [minOpen]; while the input bar is showing ([withInputBar]) it
/// is at least [kConsoleInputBarMinHeight]. The least wins over a smaller
/// [maxHeight]: a console too small for its own parts is worse than one that
/// is a little too big.
double consoleHeightFor({
  required double wanted,
  required double minOpen,
  required double maxHeight,
  bool withInputBar = false,
}) {
  final floor = withInputBar ? math.max(minOpen, kConsoleInputBarMinHeight) : minOpen;
  if (maxHeight <= floor) return floor;
  return math.min(math.max(wanted, floor), maxHeight);
}
