import 'dart:math' as math;

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

// ---------------------------------------------------------------------
// Output list
//
// Why every row has the SAME fixed height (`itemExtent`):
// a lazy ListView whose rows have different heights cannot know where row
// N starts without laying out every row before it. So every big jump —
// the auto-scroll to the newest line, or dragging the scrollbar through a
// few thousand lines — forced Flutter to lay out all the rows in between
// (seconds in a debug build), and the UI froze. With a fixed extent a jump
// is O(1).
//
// To make that possible:
//   * an event that spans several lines (stack traces, "a\nb") is split
//     into one row per line;
//   * a row never wraps. Long lines are scrolled horizontally instead.
// ---------------------------------------------------------------------

const double _kRowExtent = 22;
const double _kFontSize = 12.5;

/// Longer lines are cut off (with an ellipsis) — a single multi-megabyte
/// line would be slow to lay out.
const int _kMaxLineChars = 2000;

/// One physical line of console output.
class _ConsoleLine {
  final ConsoleEventType type;
  final String text;

  /// First line of its event: only this row shows the icon / `stderr` label.
  final bool isFirst;
  final int? exitCode;

  const _ConsoleLine({
    required this.type,
    required this.text,
    required this.isFirst,
    this.exitCode,
  });
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

  /// Flattened one-row-per-line view of the runner's events.
  final List<_ConsoleLine> _lines = [];

  /// How many of the runner's events have been flattened so far. (The old
  /// auto-scroll compared `widget.runner.events.length` with
  /// `oldWidget.runner.events.length`; both widgets hold the SAME
  /// RunnerProvider, so the lengths were always equal and it never ran.)
  int _consumed = 0;

  /// Longest line seen, in characters — sizes the horizontal scroll area.
  int _maxChars = 0;
  double? _charWidth;

  /// "At the bottom" tolerance in pixels.
  static const double _bottomTolerance = 48;

  @override
  void initState() {
    super.initState();
    _consume();
    // Console re-opened with output already in it: show the latest lines.
    if (_lines.isNotEmpty) _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---- events -> lines -------------------------------------------------

  void _consume() {
    final events = widget.runner.events;
    if (events.length < _consumed) {
      // Output was cleared / a new run started.
      _lines.clear();
      _consumed = 0;
      _maxChars = 0;
    }
    for (var i = _consumed; i < events.length; i++) {
      _addEvent(events[i]);
    }
    _consumed = events.length;
  }

  void _noteWidth(int chars) {
    if (chars > _maxChars) _maxChars = chars;
  }

  void _addEvent(ConsoleEvent e) {
    if (e.type == ConsoleEventType.exitCode) {
      final text = 'Program finished (exit code ${e.exitCode})';
      _lines.add(_ConsoleLine(
        type: e.type,
        text: text,
        isFirst: true,
        exitCode: e.exitCode,
      ));
      _noteWidth(text.length);
      return;
    }

    final pieces = (e.text ?? '').split('\n');
    for (var k = 0; k < pieces.length; k++) {
      var t = pieces[k];
      if (t.endsWith('\r')) t = t.substring(0, t.length - 1);
      if (t.length > _kMaxLineChars) {
        t = '${t.substring(0, _kMaxLineChars)}…';
      }
      final first = k == 0;
      _lines.add(_ConsoleLine(type: e.type, text: t, isFirst: first));
      // "stderr  " label takes 8 characters on the first row.
      _noteWidth(t.length + (first && e.type == ConsoleEventType.stderr ? 8 : 0));
    }
  }

  // ---- scrolling ---------------------------------------------------------

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final p = _scrollController.position;
    return p.pixels >= p.maxScrollExtent - _bottomTolerance;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void didUpdateWidget(covariant _OutputList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Decide BEFORE the new rows are laid out: if the user has scrolled up
    // to read earlier output, leave them where they are.
    final follow = _isNearBottom;
    final before = _lines.length;
    final cleared = widget.runner.events.length < _consumed;

    _consume();

    if (!cleared && _lines.length > before && follow) _scrollToBottom();
  }

  // ---- layout ------------------------------------------------------------

  double _measureCharWidth() {
    final tp = TextPainter(
      // (not `const`: editorFontFamily is not guaranteed to be a constant)
      text: TextSpan(
        text: 'MMMMMMMMMM',
        style: TextStyle(fontFamily: editorFontFamily, fontSize: _kFontSize),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final w = tp.width / 10;
    tp.dispose();
    return w;
  }

  double _contentWidth() {
    final charWidth = _charWidth ??= _measureCharWidth();
    const rowChrome = 2 * AppConstants.spaceMd + 13 + AppConstants.spaceSm + 8;
    return _maxChars * charWidth + rowChrome;
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return Center(
        child: Text(
          widget.runner.isRunning
              ? 'Running…'
              : 'Run your code to see output here',
          style: TextStyle(color: widget.scheme.gutterText, fontSize: 13),
        ),
      );
    }

    // System font scaling would make text taller than the fixed row height.
    return MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, _contentWidth());
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceMd,
                  vertical: AppConstants.spaceSm,
                ),
                itemExtent: _kRowExtent,
                itemCount: _lines.length,
                itemBuilder: (context, i) =>
                    _OutputRow(line: _lines[i], scheme: widget.scheme),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  final _ConsoleLine line;
  final EditorColorScheme scheme;

  const _OutputRow({required this.line, required this.scheme});

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
      height: _kRowExtent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 13,
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
                  fontSize: _kFontSize,
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