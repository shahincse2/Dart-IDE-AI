import 'package:flutter/material.dart';

import '../../models/console_event.dart';
import '../../utils/constants.dart';
import '../../utils/themes.dart';
import 'console_line.dart';

/// Fixed height of every console row (see [ConsoleLine]).
const double kConsoleRowExtent = 22;
const double kConsoleFontSize = 12.5;
const double kConsoleIconWidth = 13;

/// The fonts rows are drawn AND measured with. `inherit: false` makes sure
/// the row's `Text` adds nothing from the surrounding theme (letter spacing,
/// for example), so what was measured is exactly what is drawn.
TextStyle consoleTextStyle() => TextStyle(
    inherit: false, fontFamily: editorFontFamily, fontSize: kConsoleFontSize);

TextStyle consoleLabelStyle() => TextStyle(
    inherit: false,
    fontFamily: editorFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600);

/// One row of console output: icon (first row of an event only), the
/// `stderr` label column for error rows, and the text on a single line.
class ConsoleOutputRow extends StatelessWidget {
  const ConsoleOutputRow({
    super.key,
    required this.line,
    required this.scheme,
    required this.labelWidth,
  });

  final ConsoleLine line;
  final EditorColorScheme scheme;

  /// Width of the label column of `stderr` rows. Every row of an error keeps
  /// it, so wrapped lines line up under the first one.
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    switch (line.type) {
      case ConsoleEventType.stdout:
        icon = Icons.chevron_right_rounded;
        color = scheme.text;
      case ConsoleEventType.stderr:
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFE06C75);
      case ConsoleEventType.systemInfo:
        icon = Icons.info_outline_rounded;
        color = scheme.gutterText;
      case ConsoleEventType.exitCode:
        final success = line.exitCode == 0;
        icon = success
            ? Icons.check_circle_outline_rounded
            : Icons.cancel_outlined;
        color = success ? const Color(0xFF6FCF97) : const Color(0xFFE06C75);
    }

    return SizedBox(
      height: kConsoleRowExtent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: kConsoleIconWidth,
            child: line.isFirst ? Icon(icon, size: 13, color: color) : null,
          ),
          const SizedBox(width: AppConstants.spaceSm),
          if (line.type == ConsoleEventType.stderr)
            SizedBox(
              width: labelWidth,
              child: line.isFirst
                  ? Text('stderr',
                      maxLines: 1,
                      softWrap: false,
                      style: consoleLabelStyle().copyWith(color: color))
                  : null,
            ),
          Expanded(
            child: Text(
              line.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: consoleTextStyle().copyWith(color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
