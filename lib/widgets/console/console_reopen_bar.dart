import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/themes.dart';

/// A slim bar at the bottom of the editor that brings a closed console back.
///
/// Closing the console only hides it (the output is kept), so this lets the
/// user read the last output again without running the program once more.
class ConsoleReopenBar extends StatelessWidget {
  const ConsoleReopenBar({
    super.key,
    required this.scheme,
    required this.isRunning,
    required this.onTap,
  });

  final EditorColorScheme scheme;
  final bool isRunning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = scheme.gutterText.withValues(alpha: 0.2);
    return Material(
      color: scheme.gutterBackground,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: border, width: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.terminal_rounded, size: 16, color: scheme.gutterText),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                isRunning ? 'Console (running)' : 'Show console',
                style: TextStyle(color: scheme.text, fontSize: 13),
              ),
              const Spacer(),
              Icon(Icons.keyboard_arrow_up_rounded,
                  size: 20, color: scheme.gutterText),
            ],
          ),
        ),
      ),
    );
  }
}
