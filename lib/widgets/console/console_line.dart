import '../../models/console_event.dart';

/// One physical row of console output.
///
/// Every row is drawn at the same fixed height (that is what keeps jumping
/// to the newest line cheap), so an event with several lines, or a line
/// that is wider than the console, becomes several [ConsoleLine]s.
class ConsoleLine {
  const ConsoleLine({
    required this.type,
    required this.text,
    required this.isFirst,
    this.exitCode,
  });

  final ConsoleEventType type;
  final String text;

  /// First row of its event: only this row shows the icon / `stderr` label.
  final bool isFirst;
  final int? exitCode;
}
