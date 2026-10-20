import 'dart:math' as math;

/// The least height at which the console's input bar (shown while a program
/// waits for a line), its header and drag handle all still fit.
const double kConsoleInputBarMinHeight = 150;

/// The tallest the console may be right now.
///
/// Normally 70% of the screen. With the keyboard up there is little room, and
/// the editor screen has other parts too (tabs, toolbar), so the console gets
/// 30% of the height the screen's body really has ([bodyHeight]).
double consoleMaxHeight({
  required double screenHeight,
  required double bodyHeight,
  required bool keyboardVisible,
}) {
  if (!keyboardVisible) return screenHeight * 0.7;
  return math.max(0.0, bodyHeight) * 0.3;
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
