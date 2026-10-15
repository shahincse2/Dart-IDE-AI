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
  const ConsolePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final console = context.watch<ConsoleProvider>();
    final runner = context.watch<RunnerProvider>();
    final themeName =
        context.select<SettingsProvider, String>((s) => s.editorThemeName);
    final scheme = editorSchemeFromName(themeName);
    final media = MediaQuery.of(context);
    // How tall the console may be right now (less while the keyboard is up).
    final maxHeight = consoleMaxHeight(
      screenHeight: media.size.height,
      keyboardHeight: media.viewInsets.bottom,
    );
    // The drag handle keeps its old, keyboard-free limit.
    final dragLimit = consoleMaxHeight(
      screenHeight: media.size.height,
      keyboardHeight: 0,
    );
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
        AnimatedContainer(
          duration: AppConstants.animBase,
          curve: Curves.easeOutCubic,
          height: console.isOpen
              ? consoleHeightFor(
                  wanted: console.height,
                  minOpen: AppConstants.consoleMinOpenHeight,
                  maxHeight: maxHeight,
                )
              : 0,
          decoration: BoxDecoration(
            color: scheme.gutterBackground,
            border: Border(
                top: BorderSide(
                    color: scheme.gutterText.withValues(alpha: 0.2),
                    width: 0.5)),
          ),
          clipBehavior: Clip.hardEdge,
          child: console.isOpen
              ? _ConsoleContent(
                  console: console,
                  runner: runner,
                  scheme: scheme,
                  maxHeight: dragLimit,
                )
              : null,
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
