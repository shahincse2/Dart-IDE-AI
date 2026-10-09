import 'package:flutter/material.dart';

import '../../models/console_event.dart';
import '../../utils/constants.dart';
import '../../utils/themes.dart';
import 'console_line.dart';

/// Fixed height of every console row (see [ConsoleLine]).
const double kConsoleRowExtent = 22;
const double kConsoleFontSize = 12.5;
const double kConsoleIconWidth = 13;

/// Room kept free on every row for the `stderr  ` label.
const int kConsoleLabelChars = 8;

/// One row of console output: icon (first row of an event only), optional
/// `stderr` label, and the text on a single line.
class ConsoleOutputRow extends StatelessWidget {
  const ConsoleOutputRow({super.key, required this.line, required this.scheme});

  final ConsoleLine line;
  final EditorColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    String? label;

    switch (line.type) {
      case ConsoleEventType.stdout:
        icon = Icons.chevron_right_rounded;
        color = scheme.text;
      case ConsoleEventType.stderr:
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFE06C75);
        label = 'stderr';
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
          if (label != null && line.isFirst)
            Text(
              '$label  ',
              style: TextStyle(
                  color: color,
                  fontFamily: editorFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          Expanded(
            child: Text(
              line.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color,
                  fontFamily: editorFontFamily,
                  fontSize: kConsoleFontSize,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
