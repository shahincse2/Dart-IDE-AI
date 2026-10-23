import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/console_provider.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';
import 'console/console_drag_handle.dart';
import 'console/console_header.dart';
import 'console/console_height.dart';
import 'console/console_output_list.dart';
import 'console/console_reopen_bar.dart';
import 'console/console_stdin_bar.dart';

/// The real Console panel (Section 26-31):
///   - Hidden by default; animates up on Run or on an error
///   - Drag handle to resize
///   - stdout vs stderr distinguished by icon + color + label
///   - Copy / Save-as-.txt / Clear / Close
///   - stdin input bar (Phase stdin) — appears when interpreted code
///     calls readLineSync(), disappears once the user sends a reply
class ConsolePanel extends StatelessWidget {
  /// How much room the screen has left for the console (its body, minus its
  /// other parts and a usable editor). The editor screen measures it, so the
  /// console never pushes the other parts off the screen, with the keyboard
  /// up or not. Null: not known, only the 70%-of-the-screen limit applies.
  final double? roomHeight;

  const ConsolePanel({super.key, this.roomHeight});

  @override
  Widget build(BuildContext context) {
    final console = context.watch<ConsoleProvider>();
    final runner = context.watch<RunnerProvider>();
    final themeName =
        context.select<SettingsProvider, String>((s) => s.editorThemeName);
    final scheme = editorSchemeFromName(themeName);
    final screenHeight = MediaQuery.sizeOf(context).height;
    // How tall the console may be right now.
    final maxHeight = consoleMaxHeight(
      screenHeight: screenHeight,
      roomHeight: roomHeight,
    );
    // The drag handle keeps its own limit, whatever the room is right now: the
    // height the user chose is kept when the keyboard goes away again.
    final dragLimit = consoleMaxHeight(screenHeight: screenHeight);
    final height = console.isOpen
        ? consoleHeightFor(
            wanted: console.height,
            minOpen: AppConstants.consoleMinOpenHeight,
            maxHeight: maxHeight,
            withInputBar: runner.waitingForStdin,
          )
        : 0.0;
    // Closing the console only hides it, so offer a way back to its output.
    final canReopen =
        !console.isOpen && (runner.isRunning || runner.events.isNotEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canReopen)
          ConsoleReopenBar(
            scheme: scheme,
            isRunning: runner.isRunning,
            onTap: console.open,
          ),
        // The clamp is instant: when the room shrinks (the keyboard opening) the
        // console must not stay too tall for the frames the animation needs.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: console.isOpen ? height : double.infinity,
          ),
          child: AnimatedContainer(
            duration: AppConstants.animBase,
            curve: Curves.easeOutCubic,
            height: height,
            decoration: BoxDecoration(
              color: scheme.gutterBackground,
              border: Border(
                  top: BorderSide(
                      color: scheme.gutterText.withValues(alpha: 0.2),
                      width: 0.5)),
            ),
            clipBehavior: Clip.hardEdge,
            // The content is laid out at the console's FINAL height. While the box
            // is still growing (opening, or the input bar appearing) it is
            // clipped, never squeezed: a squeezed Column overflows.
            child: console.isOpen
                ? OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: height,
                    maxHeight: height,
                    child: _ConsoleContent(
                      console: console,
                      runner: runner,
                      scheme: scheme,
                      maxHeight: dragLimit,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _ConsoleContent extends StatelessWidget {
  final ConsoleProvider console;
  final RunnerProvider runner;
  final EditorColorScheme scheme;
  final double maxHeight;

  const _ConsoleContent({
    required this.console,
    required this.runner,
    required this.scheme,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConsoleDragHandle(console: console, maxHeight: maxHeight),
        ConsoleHeader(console: console, runner: runner, scheme: scheme),
        Divider(height: 0.5, color: scheme.gutterText.withValues(alpha: 0.15)),
        Expanded(child: ConsoleOutputList(runner: runner, scheme: scheme)),
        // stdin input field — only visible when interpreted code is
        // blocked waiting for readLineSync() input (Section 31).
        if (runner.waitingForStdin)
          ConsoleStdinBar(runner: runner, scheme: scheme),
      ],
    );
  }
}
