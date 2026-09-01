import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/themes.dart';
import 'code_editor_controller.dart';

/// The editing surface itself: a line-number gutter kept in lockstep
/// with the text via a shared [ScrollController] (Section 9 —
/// "line number editor-এর সঙ্গে vertically synchronized থাকতে হবে"),
/// a subtle current-line highlight (Section 10), and the text field
/// wired to [CodeEditorController] for highlighting/bracket-matching/
/// auto-indent.
///
/// The gutter's line positions are computed from a fixed line height
/// (`fontSize * editorLineHeight`) rather than measuring the actual
/// TextField layout. The TextField is given a matching `strutStyle`
/// with `forceStrutHeight: true`, which pins every rendered line to
/// exactly that height — without it, the font's own ascent/descent
/// metrics would produce a slightly different line height, and that
/// small mismatch would compound into visible drift over a long file.
///
/// Reactivity is deliberately a single listener on this State, rather
/// than separate `AnimatedBuilder`s inside the gutter and the
/// highlight each building their own `Listenable.merge(...)`. Building
/// a fresh merged listenable on every rebuild, in more than one place,
/// made it possible for the gutter and the highlight to redraw a frame
/// apart from the text field and from each other — visible as the
/// gutter's line numbers lagging behind newly typed lines. One
/// `setState` rebuilding the whole subtree together removes that
/// possibility entirely: every part reads the same controller/scroll
/// state at the same synchronous moment.
///
/// This widget is NOT re-keyed per open tab in EditorScreen. Forcing a
/// remount on every tab switch was tried and caused the cursor to
/// visually reset to the start of the file — a fresh FocusNode/
/// EditableText has no memory of where the previous one's caret was.
/// Letting `didUpdateWidget` swap the controller in place keeps the
/// same FocusNode/EditableText alive across switches, so the cursor
/// position — which lives on the controller, not this widget — carries
/// over correctly. Only the scroll offset is deliberately reset.
class CodeEditor extends StatefulWidget {
  final CodeEditorController controller;
  final double fontSize;

  const CodeEditor({
    super.key,
    required this.controller,
    this.fontSize = AppConstants.defaultFontSize,
  });

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  double get _lineHeight => widget.fontSize * AppConstants.editorLineHeight;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onEditorChanged);
    _scrollController.addListener(_onEditorChanged);
  }

  @override
  void didUpdateWidget(covariant CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onEditorChanged);
      widget.controller.addListener(_onEditorChanged);
      // Switching to a different file's controller: start scrolled to
      // the top rather than wherever the previous file's viewport
      // happened to be. The cursor/selection needs no special handling
      // here — it lives on the controller we just swapped in, so
      // TextField picks it up automatically.
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void _onEditorChanged() {
    setState(() {});
    // Runs after the frame renders, once _scrollController actually
    // has a viewport to measure. Needed for Find & Replace navigation
    // and Go to Line (Phase 7) — setting `controller.selection`
    // programmatically doesn't auto-scroll the way typing does.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCursorVisible());
  }

  void _ensureCursorVisible() {
    if (!mounted || !_scrollController.hasClients) return;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;

    final text = widget.controller.text;
    final offset = selection.baseOffset.clamp(0, text.length);
    final lineIndex = '\n'.allMatches(text.substring(0, offset)).length;
    final lineTop = lineIndex * _lineHeight;
    final lineBottom = lineTop + _lineHeight;

    final viewTop = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final viewBottom = viewTop + viewportHeight;

    if (lineTop < viewTop) {
      _scrollController.animateTo(lineTop, duration: AppConstants.animFast, curve: Curves.easeOut);
    } else if (lineBottom > viewBottom) {
      _scrollController.animateTo(
        lineBottom - viewportHeight,
        duration: AppConstants.animFast,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onEditorChanged);
    _scrollController.removeListener(_onEditorChanged);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _lineCountOf(String text) => '\n'.allMatches(text).length + 1;

  int _currentLineIndex() {
    final offset = widget.controller.selection.baseOffset;
    if (offset < 0) return -1;
    final text = widget.controller.text;
    final clamped = offset.clamp(0, text.length);
    return '\n'.allMatches(text.substring(0, clamped)).length;
  }

  double _gutterWidthFor(int lineCount) {
    final digits = lineCount.toString().length;
    return (digits * widget.fontSize * 0.62) + AppConstants.spaceMd + AppConstants.spaceXs;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.controller.scheme;
    final lineCount = _lineCountOf(widget.controller.text);
    final currentLine = _currentLineIndex();
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final gutterWidth = _gutterWidthFor(lineCount);

    return ColoredBox(
      color: scheme.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LineNumberGutter(
            scheme: scheme,
            lineHeight: _lineHeight,
            fontSize: widget.fontSize,
            width: gutterWidth,
            lineCount: lineCount,
            currentLine: currentLine,
            scrollOffset: scrollOffset,
          ),
          Container(width: 0.5, color: scheme.gutterText.withOpacity(0.15)),
          Expanded(
            child: Stack(
              children: [
                _CurrentLineHighlight(
                  scheme: scheme,
                  lineHeight: _lineHeight,
                  currentLine: currentLine,
                  scrollOffset: scrollOffset,
                  hasSelection:
                      widget.controller.selection.isValid && widget.controller.selection.isCollapsed,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: AppConstants.spaceSm),
                  child: TextField(
                    controller: widget.controller,
                    scrollController: _scrollController,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    cursorColor: scheme.cursor,
                    cursorWidth: 2,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(
                      fontFamily: editorFontFamily,
                      fontSize: widget.fontSize,
                      height: AppConstants.editorLineHeight,
                      color: scheme.text,
                    ),
                    strutStyle: StrutStyle(
                      fontFamily: editorFontFamily,
                      fontSize: widget.fontSize,
                      height: AppConstants.editorLineHeight,
                      forceStrutHeight: true,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineNumberGutter extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final double fontSize;
  final double width;
  final int lineCount;
  final int currentLine;
  final double scrollOffset;

  const _LineNumberGutter({
    required this.scheme,
    required this.lineHeight,
    required this.fontSize,
    required this.width,
    required this.lineCount,
    required this.currentLine,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    // Each line number is absolutely positioned inside a Stack rather
    // than stacked in a Column. A Column asserts (and overflows)
    // whenever its children's combined height exceeds what its parent
    // hands it — which happens for any file with more lines than fit
    // on screen. A Stack has no such assertion: children beyond its
    // bounds are simply clipped (Stack's default clipBehavior is
    // Clip.hardEdge), so this works regardless of file length.
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: scheme.gutterBackground,
        child: Stack(
          children: List.generate(lineCount, (i) {
            final isCurrent = i == currentLine;
            return Positioned(
              top: (i * lineHeight) - scrollOffset,
              left: 0,
              right: 0,
              height: lineHeight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppConstants.spaceSm),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontFamily: editorFontFamily,
                      fontSize: fontSize * 0.85,
                      color: isCurrent ? scheme.text : scheme.gutterText,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _CurrentLineHighlight extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final int currentLine;
  final double scrollOffset;
  final bool hasSelection;

  const _CurrentLineHighlight({
    required this.scheme,
    required this.lineHeight,
    required this.currentLine,
    required this.scrollOffset,
    required this.hasSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSelection || currentLine < 0) return const SizedBox.shrink();

    final top = (currentLine * lineHeight) - scrollOffset;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: lineHeight,
      child: IgnorePointer(
        child: ColoredBox(color: scheme.currentLine),
      ),
    );
  }
}
