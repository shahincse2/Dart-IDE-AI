import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../models/console_event.dart';
import '../providers/console_provider.dart';
import '../providers/runner_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';

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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return AnimatedContainer(
      duration: AppConstants.animBase,
      curve: Curves.easeOutCubic,
      height: console.isOpen
          ? console.height.clamp(AppConstants.consoleMinOpenHeight, maxHeight)
          : 0,
      decoration: BoxDecoration(
        color: scheme.gutterBackground,
        border: Border(
            top: BorderSide(
                color: scheme.gutterText.withValues(alpha: 0.2), width: 0.5)),
      ),
      clipBehavior: Clip.hardEdge,
      child: console.isOpen
          ? _ConsoleContent(
              console: console,
              runner: runner,
              scheme: scheme,
              maxHeight: maxHeight,
            )
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
        // stdin input field — only visible when interpreted code is
        // blocked waiting for readLineSync() input (Section 31).
        if (runner.waitingForStdin)
          _StdinInputBar(runner: runner, scheme: scheme),
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
        console.setHeight(console.height - details.delta.dy,
            maxHeight: maxHeight);
      },
      child: SizedBox(
        height: AppConstants.consoleDragHandleHeight,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
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

  const _Header({
    required this.console,
    required this.runner,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    Widget action(String tip, IconData icon, VoidCallback onTap) => IconButton(
          tooltip: tip,
          icon: Icon(icon, size: 18, color: scheme.gutterText),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onTap,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        0,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Console',
                    style: TextStyle(
                        color: scheme.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  if (runner.isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.selection.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Running',
                          style: TextStyle(color: scheme.text, fontSize: 11)),
                    ),
                  if (runner.waitingForStdin)
                    Container(
                      margin: const EdgeInsets.only(left: AppConstants.spaceSm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.type.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Waiting for input',
                          style: TextStyle(color: scheme.type, fontSize: 11)),
                    ),
                ],
              ),
            ),
          ),
          action('Copy output', Icons.copy_outlined, () async {
            await console.copyToClipboard();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')));
            }
          }),
          action('Save as .txt', Icons.download_outlined, () async {
            final path = await console.saveToFile();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Output saved'),
                  action: SnackBarAction(
                    label: 'Open folder',
                    onPressed: () => OpenFilex.open(path),
                  ),
                ),
              );
            }
          }),
          action('Clear', Icons.delete_outline, console.clear),
          action('Close', Icons.close, console.close),
        ],
      ),
    );
  }
}

class _OutputList extends StatefulWidget {
  final RunnerProvider runner;
  final EditorColorScheme scheme;

  const _OutputList({required this.runner, required this.scheme});

  @override
  State<_OutputList> createState() => _OutputListState();
}

class _OutputListState extends State<_OutputList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OutputList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new output arrives.
    if (widget.runner.events.length != oldWidget.runner.events.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: AppConstants.animFast,
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.runner.events.isEmpty) {
      return Center(
        child: Text(
          widget.runner.isRunning
              ? 'Running…'
              : 'Run your code to see output here',
          style: TextStyle(color: widget.scheme.gutterText, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMd, vertical: AppConstants.spaceSm),
      itemCount: widget.runner.events.length,
      itemBuilder: (context, i) =>
          _OutputRow(event: widget.runner.events[i], scheme: widget.scheme),
    );
  }
}

class _OutputRow extends StatelessWidget {
  final ConsoleEvent event;
  final EditorColorScheme scheme;

  const _OutputRow({required this.event, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String text;
    String? label;

    switch (event.type) {
      case ConsoleEventType.stdout:
        icon = Icons.chevron_right_rounded;
        color = scheme.text;
        text = event.text ?? '';
      case ConsoleEventType.stderr:
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFE06C75);
        text = event.text ?? '';
        label = 'stderr';
      case ConsoleEventType.systemInfo:
        icon = Icons.info_outline_rounded;
        color = scheme.gutterText;
        text = event.text ?? '';
      case ConsoleEventType.exitCode:
        final success = event.exitCode == 0;
        icon = success
            ? Icons.check_circle_outline_rounded
            : Icons.cancel_outlined;
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
          if (label != null)
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
              text,
              style: TextStyle(
                  color: color,
                  fontFamily: editorFontFamily,
                  fontSize: 12.5,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stdin input bar — appears only when interpreted code calls
/// readLineSync() and the program is blocked waiting for input.
class _StdinInputBar extends StatefulWidget {
  final RunnerProvider runner;
  final EditorColorScheme scheme;

  const _StdinInputBar({required this.runner, required this.scheme});

  @override
  State<_StdinInputBar> createState() => _StdinInputBarState();
}

class _StdinInputBarState extends State<_StdinInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus so the user can type immediately without tapping.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    widget.runner.submitStdinInput(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
      ),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: widget.scheme.gutterText.withValues(alpha: 0.2),
                width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.keyboard_return_rounded,
              size: 16, color: widget.scheme.type),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                  fontFamily: editorFontFamily,
                  fontSize: 13,
                  color: widget.scheme.text),
              decoration: InputDecoration(
                hintText: 'Type input and press Send…',
                hintStyle: TextStyle(color: widget.scheme.gutterText),
                border: InputBorder.none,
                isDense: true,
                isCollapsed: true,
              ),
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _send(),
            ),
          ),
          TextButton(
            onPressed: _send,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
