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
  final UndoHistoryController? undoController;
  final bool wordWrap;

  const CodeEditor({
    super.key,
    required this.controller,
    this.fontSize = AppConstants.defaultFontSize,
    this.undoController,
    this.wordWrap = true,
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
    widget.controller.addListener(_onControllerChanged);
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(covariant CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
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

  /// Text or selection changed — redraw, and auto-scroll the cursor
  /// into view (Find & Replace navigation, Go to Line, typing past the
  /// bottom edge).
  void _onControllerChanged() {
    setState(() {});
    // Runs after the frame renders, once _scrollController actually
    // has a viewport to measure.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCursorVisible());
  }

  /// The user scrolled (or `_ensureCursorVisible` did) — just redraw
  /// the gutter/current-line-highlight to track the new offset.
  /// Deliberately does NOT call `_ensureCursorVisible`: that was the
  /// bug — with both events wired to the same handler, every manual
  /// scroll away from the cursor's line immediately triggered an
  /// auto-scroll back to it, so scrolling through anything longer than
  /// one screen felt broken (it kept snapping back).
  void _onScrollChanged() {
    setState(() {});
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
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.removeListener(_onScrollChanged);
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

  /// Rough monospace-character-width estimate for the longest line —
  /// used only to size the horizontal scroll area when word wrap is
  /// off. Doesn't need to be pixel-exact, just wide enough that the
  /// longest line isn't clipped.
  double _longestLineWidth(String text) {
    var maxChars = 0;
    for (final line in text.split('\n')) {
      if (line.length > maxChars) maxChars = line.length;
    }
    return maxChars * widget.fontSize * 0.62;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.controller.scheme;
    final lineCount = _lineCountOf(widget.controller.text);
    final currentLine = _currentLineIndex();
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final viewportHeight =
        _scrollController.hasClients ? _scrollController.position.viewportDimension : null;
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
            viewportHeight: viewportHeight,
          ),
          Container(width: 0.5, color: scheme.gutterText.withOpacity(0.15)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final editorStack = Stack(
                  children: [
                    _CurrentLineHighlight(
                      scheme: scheme,
                      lineHeight: _lineHeight,
                      currentLine: currentLine,
                      scrollOffset: scrollOffset,
                      hasSelection: widget.controller.selection.isValid &&
                          widget.controller.selection.isCollapsed,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: AppConstants.spaceSm),
                      child: TextField(
                        controller: widget.controller,
                        scrollController: _scrollController,
                        focusNode: _focusNode,
                        undoController: widget.undoController,
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
                );

                if (widget.wordWrap) return editorStack;

                // Word wrap off: give the editor a fixed width wide
                // enough for its longest line, inside a horizontal
                // scroll view, instead of letting TextField wrap long
                // lines the way it does by default. The gutter stays
                // outside this scroll view (see the Row above), so line
                // numbers remain visible while code scrolls under them.
                final contentWidth = [
                  _longestLineWidth(widget.controller.text) + AppConstants.spaceLg,
                  constraints.maxWidth,
                ].reduce((a, b) => a > b ? a : b);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: contentWidth,
                    height: constraints.maxHeight,
                    child: editorStack,
                  ),
                );
              },
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
  final double? viewportHeight;

  const _LineNumberGutter({
    required this.scheme,
    required this.lineHeight,
    required this.fontSize,
    required this.width,
    required this.lineCount,
    required this.currentLine,
    required this.scrollOffset,
    required this.viewportHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Only the lines actually near the visible viewport get built —
    // for a long file, generating a Positioned+Text for every single
    // line on every scroll frame (most of them off-screen) was the
    // real cause of scrolling feeling janky rather than smooth. A
    // Stack still can't overflow-assert (Section: gutter overflow fix)
    // since we're just choosing not to add most children, not asking
    // it to lay out fewer than it's given.
    int firstVisible;
    int lastVisible;
    if (viewportHeight == null) {
      // No layout measurement yet (first frame) — render everything
      // once; this only affects the very first build.
      firstVisible = 0;
      lastVisible = lineCount - 1;
    } else {
      const buffer = 4; // extra lines above/below so fast flings don't show a blank edge
      firstVisible = (scrollOffset / lineHeight).floor() - buffer;
      lastVisible = ((scrollOffset + viewportHeight!) / lineHeight).ceil() + buffer;
      firstVisible = firstVisible.clamp(0, lineCount - 1);
      lastVisible = lastVisible.clamp(0, lineCount - 1);
    }

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: scheme.gutterBackground,
        child: Stack(
          children: [
            for (var i = firstVisible; i <= lastVisible; i++)
              Positioned(
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
                        color: i == currentLine ? scheme.text : scheme.gutterText,
                        fontWeight: i == currentLine ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
