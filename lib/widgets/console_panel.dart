import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/console_event.dart';
import '../providers/console_provider.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';

/// The real Console panel (Section 26-30), replacing Phase 3's plain
/// temporary output list:
///   - Hidden by default; animates up from the bottom on Run or on an
///     error (ConsoleProvider decides when, this widget just reflects it)
///   - Drag handle to resize
///   - stdout vs stderr distinguished by icon + color + label, not
///     color alone (Section 30 — accessibility)
///   - Copy / Save-as-.txt / Clear / Close actions
///
/// Deliberately NOT included here: a duplicate Stop button (the app
/// bar already has one — Section 33's requirement is satisfied there,
/// and repeating run-control state in two places invites them drifting
/// out of sync) and the stdin input bar (Phase 8, once interactive
/// stdin bridging has been verified against tom_d4rt on a real device).
class ConsolePanel extends StatelessWidget {
  const ConsolePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final console = context.watch<ConsoleProvider>();
    final runner = context.watch<RunnerProvider>();
    final themeName = context.select<SettingsProvider, String>((s) => s.editorThemeName);
    final scheme = editorSchemeFromName(themeName);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return AnimatedContainer(
      duration: AppConstants.animBase,
      curve: Curves.easeOutCubic,
      height: console.isOpen ? console.height.clamp(AppConstants.consoleMinOpenHeight, maxHeight) : 0,
      decoration: BoxDecoration(
        color: scheme.gutterBackground,
        border: Border(top: BorderSide(color: scheme.gutterText.withValues(alpha: 0.2), width: 0.5)),
      ),
      clipBehavior: Clip.hardEdge,
      child: console.isOpen
          ? _ConsoleContent(console: console, runner: runner, scheme: scheme, maxHeight: maxHeight)
          : null,
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
        _DragHandle(console: console, maxHeight: maxHeight),
        _Header(console: console, runner: runner, scheme: scheme),
        Divider(height: 0.5, color: scheme.gutterText.withValues(alpha: 0.15)),
        Expanded(child: _OutputList(runner: runner, scheme: scheme)),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  final ConsoleProvider console;
  final double maxHeight;

  const _DragHandle({required this.console, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        console.setHeight(console.height - details.delta.dy, maxHeight: maxHeight);
      },
      child: SizedBox(
        height: AppConstants.consoleDragHandleHeight,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ConsoleProvider console;
  final RunnerProvider runner;
  final EditorColorScheme scheme;

  const _Header({required this.console, required this.runner, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        0,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          Text('Console', style: TextStyle(color: scheme.text, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: AppConstants.spaceSm),
          if (runner.isRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.selection.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Running', style: TextStyle(color: scheme.text, fontSize: 11)),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Copy output',
            icon: Icon(Icons.copy_outlined, size: 18, color: scheme.gutterText),
            onPressed: () async {
              await console.copyToClipboard();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
              }
            },
          ),
          IconButton(
            tooltip: 'Save as .txt',
            icon: Icon(Icons.download_outlined, size: 18, color: scheme.gutterText),
            onPressed: () async {
              final path = await console.saveToFile();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Saved to $path')));
              }
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: Icon(Icons.delete_outline, size: 18, color: scheme.gutterText),
            onPressed: console.clear,
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close, size: 18, color: scheme.gutterText),
            onPressed: console.close,
          ),
        ],
      ),
    );
  }
}

class _OutputList extends StatelessWidget {
  final RunnerProvider runner;
  final EditorColorScheme scheme;

  const _OutputList({required this.runner, required this.scheme});

  @override
  Widget build(BuildContext context) {
    if (runner.events.isEmpty) {
      return Center(
        child: Text(
          runner.isRunning ? 'Running…' : 'Run your code to see output here',
          style: TextStyle(color: scheme.gutterText, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSm),
      itemCount: runner.events.length,
      itemBuilder: (context, i) => _OutputRow(event: runner.events[i], scheme: scheme),
    );
  }
}

class _OutputRow extends StatelessWidget {
  final ConsoleEvent event;
  final EditorColorScheme scheme;

  const _OutputRow({required this.event, required this.scheme});

  @override
  Widget build(BuildContext context) {
    // stdout vs stderr is never color-only: each row also gets a
    // distinct icon and, for stderr, an explicit "stderr" label
    // (Section 30).
    final IconData icon;
    final Color color;
    final String text;

    switch (event.type) {
      case ConsoleEventType.stdout:
        icon = Icons.chevron_right_rounded;
        color = scheme.text;
        text = event.text ?? '';
      case ConsoleEventType.stderr:
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFE06C75);
        text = event.text ?? '';
      case ConsoleEventType.systemInfo:
        icon = Icons.info_outline_rounded;
        color = scheme.gutterText;
        text = event.text ?? '';
      case ConsoleEventType.exitCode:
        final success = event.exitCode == 0;
        icon = success ? Icons.check_circle_outline_rounded : Icons.cancel_outlined;
        color = success ? const Color(0xFF6FCF97) : const Color(0xFFE06C75);
        text = 'Program finished (exit code ${event.exitCode})';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          if (event.type == ConsoleEventType.stderr)
            Text('stderr  ', style: TextStyle(color: color, fontFamily: editorFontFamily, fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontFamily: editorFontFamily, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
