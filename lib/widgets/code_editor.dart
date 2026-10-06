import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/themes.dart';
import 'code_editor_controller.dart';

/// The editing surface itself: a line-number gutter kept in lockstep
/// with the text via a shared [ScrollController] (Section 9), a subtle
/// current-line highlight (Section 10), and the text field wired to
/// [CodeEditorController] for highlighting/bracket-matching/auto-indent.
///
/// Gutter alignment (mobile fix):
///
/// 1. System text scaling is switched off for the whole editor area
///    (`MediaQuery.withNoTextScaling`). Phones commonly run with a
///    font scale > 1.0 (e.g. Samsung's font-size setting). The
///    TextField scales its text AND its strut, so its rows became
///    taller than `fontSize * editorLineHeight`, while the gutter —
///    positioned from that unscaled number — stayed shorter. The gap
///    compounded line after line. The editor's own Font size dialog
///    is the single source of truth for size now.
///
/// 2. Word wrap: on a narrow screen one logical line can occupy several
///    visual rows. The gutter used to assume exactly one row per
///    logical line, so every number after a wrapped line sat one row
///    too high. We now measure how many rows each logical line takes
///    (TextPainter, same style/strut/width as the TextField) and place
///    gutter numbers, the current-line highlight and the error
///    highlight by visual row. Results are cached per line, so typing
///    only re-measures the line that changed.
///
/// Reactivity is deliberately a single listener on this State: one
/// `setState` rebuilds gutter, highlights and text field together.
///
/// This widget is NOT re-keyed per open tab in EditorScreen — see the
/// notes in EditorScreen: swapping the controller in `didUpdateWidget`
/// keeps the cursor position across tab switches.
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

  /// Flutter's text layout reserves `cursorWidth + 1px gap` on the right
  /// of the wrapping width. cursorWidth is 2 below.
  static const double _caretMargin = 3.0;

  // ---- Row-layout cache -------------------------------------------------
  final Map<String, int> _lineRowsCache = {};
  final Map<String, double> _lineWidthCache = {};

  /// Natural width of the widest line (word wrap OFF only).
  double _maxLineWidth = 0;

  /// `_rowStarts[i]` = first visual row of logical line i.
  /// `_rowStarts.last` = total visual rows. Length = lineCount + 1.
  List<int> _rowStarts = const [0];

  String? _layoutText;
  double _layoutWidth = -1;
  double _layoutFontSize = -1;
  bool _layoutWrap = true;
  TextStyle? _measureStyle;
  double _measureWidth = 1;
  double _charWidth = 0;

  double get _lineHeight => widget.fontSize * AppConstants.editorLineHeight;

  StrutStyle get _strutStyle => StrutStyle(
        fontFamily: editorFontFamily,
        fontSize: widget.fontSize,
        height: AppConstants.editorLineHeight,
        forceStrutHeight: true,
      );

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
      // the top. The cursor/selection lives on the controller, so
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCursorVisible());
  }

  /// The user scrolled — just redraw the gutter/highlights to track the
  /// new offset. Deliberately does NOT call `_ensureCursorVisible`
  /// (that made manual scrolling snap back to the cursor).
  void _onScrollChanged() {
    setState(() {});
  }

  void _ensureCursorVisible() {
    if (!mounted || !_scrollController.hasClients) return;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;

    final text = widget.controller.text;
    final offset = selection.baseOffset.clamp(0, text.length).toInt();
    final before = text.substring(0, offset);
    final lineIndex = '\n'.allMatches(before).length;
    final lineStart = before.lastIndexOf('\n') + 1;

    if (lineIndex >= _rowStarts.length - 1) return;

    // With word wrap, the caret may sit on a later visual row of its
    // logical line — find which one.
    var rowInLine = 0;
    final style = _measureStyle;
    if (widget.wordWrap && style != null && offset > lineStart) {
      var lineEnd = text.indexOf('\n', offset);
      if (lineEnd == -1) lineEnd = text.length;
      final tp = TextPainter(
        text: TextSpan(text: text.substring(lineStart, lineEnd), style: style),
        strutStyle: _strutStyle,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: _measureWidth);
      final dy = tp
          .getOffsetForCaret(
              TextPosition(offset: offset - lineStart), Rect.zero)
          .dy;
      tp.dispose();
      rowInLine = (dy / _lineHeight).floor();
    }

    final lineTop = (_rowStarts[lineIndex] + rowInLine) * _lineHeight;
    final lineBottom = lineTop + _lineHeight;

    final viewTop = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final viewBottom = viewTop + viewportHeight;

    if (lineTop < viewTop) {
      _scrollController.animateTo(lineTop,
          duration: AppConstants.animFast, curve: Curves.easeOut);
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
    return (digits * widget.fontSize * 0.62) +
        AppConstants.spaceMd +
        AppConstants.spaceXs;
  }

  /// Natural (unwrapped) width of one line, cached by text. Plain-ASCII
  /// lines in a monospace font are exactly `length * charWidth` (the
  /// measured char width already includes the style's letterSpacing);
  /// anything else is measured with a TextPainter.
  double _widthForLine(String line) {
    if (line.isEmpty) return 0;
    final cached = _lineWidthCache[line];
    if (cached != null) return cached;

    double w;
    if (_isPlainAscii(line)) {
      w = line.length * _charWidth;
    } else {
      final tp = TextPainter(
        text: TextSpan(text: line, style: _measureStyle),
        strutStyle: _strutStyle,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      w = tp.width;
      tp.dispose();
    }
    _lineWidthCache[line] = w;
    return w;
  }

  /// The exact style the TextField renders with. TextField merges the
  /// Material text theme (bodyLarge in M3, which carries a letterSpacing)
  /// under the style we pass, so we do the same merge here and pass the
  /// result to the TextField — measuring and rendering then agree.
  TextStyle _editorTextStyle(BuildContext context, EditorColorScheme scheme) {
    final theme = Theme.of(context);
    final base = (theme.useMaterial3
            ? theme.textTheme.bodyLarge
            : theme.textTheme.titleMedium) ??
        const TextStyle();
    return base.merge(
      TextStyle(
        fontFamily: editorFontFamily,
        fontSize: widget.fontSize,
        height: AppConstants.editorLineHeight,
        color: scheme.text,
      ),
    );
  }

  double _measureCharWidth(TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: 'MMMMMMMMMM', style: style),
      strutStyle: _strutStyle,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final w = tp.width / 10;
    tp.dispose();
    return w;
  }

  static bool _isPlainAscii(String s) {
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c > 126 || c == 9) return false;
    }
    return true;
  }

  /// How many visual rows one logical line occupies at the current
  /// wrapping width. Cached by line text.
  int _rowsForLine(String line) {
    if (line.isEmpty) return 1;
    final cached = _lineRowsCache[line];
    if (cached != null) return cached;

    int rows;
    if (line.length * _charWidth <= _measureWidth && _isPlainAscii(line)) {
      rows = 1; // certainly fits on one row, skip the TextPainter
    } else {
      final tp = TextPainter(
        text: TextSpan(text: line, style: _measureStyle),
        strutStyle: _strutStyle,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: _measureWidth);
      rows = math.max(1, tp.computeLineMetrics().length);
      tp.dispose();
    }
    _lineRowsCache[line] = rows;
    return rows;
  }

  /// Rebuilds [_rowStarts] when the text, wrapping width, font size,
  /// wrap mode or style changed; otherwise returns immediately.
  void _ensureRowLayout({
    required String text,
    required double wrapWidth,
    required TextStyle style,
  }) {
    final wrap = widget.wordWrap;
    final measureUnchanged = _layoutWidth == wrapWidth &&
        _layoutFontSize == widget.fontSize &&
        _layoutWrap == wrap &&
        _measureStyle == style;
    if (measureUnchanged && _layoutText == text) return;

    if (!measureUnchanged) {
      _lineRowsCache.clear();
      _lineWidthCache.clear();
    }
    if (_lineRowsCache.length > 4000) _lineRowsCache.clear();
    if (_lineWidthCache.length > 4000) _lineWidthCache.clear();

    _measureStyle = style;
    _measureWidth = wrapWidth;
    _layoutWidth = wrapWidth;
    _layoutFontSize = widget.fontSize;
    _layoutWrap = wrap;
    _layoutText = text;
    if (!measureUnchanged) _charWidth = _measureCharWidth(style);

    final lines = text.split('\n');
    final starts = List<int>.filled(lines.length + 1, 0);
    var rows = 0;
    var maxWidth = 0.0;
    for (var i = 0; i < lines.length; i++) {
      starts[i] = rows;
      if (wrap) {
        rows += _rowsForLine(lines[i]);
      } else {
        rows += 1;
        final w = _widthForLine(lines[i]);
        if (w > maxWidth) maxWidth = w;
      }
    }
    starts[lines.length] = rows;
    _rowStarts = starts;
    _maxLineWidth = maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.controller.scheme;
    final text = widget.controller.text;
    final lineCount = _lineCountOf(text);
    final currentLine = _currentLineIndex();
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final viewportHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : null;
    final gutterWidth = _gutterWidthFor(lineCount);
    final textStyle = _editorTextStyle(context, scheme);

    return MediaQuery.withNoTextScaling(
      child: ColoredBox(
        color: scheme.background,
        child: LayoutBuilder(
          builder: (context, outer) {
            // gutter + 0.5px divider + left padding of the text field
            final textAreaWidth =
                outer.maxWidth - gutterWidth - 0.5 - AppConstants.spaceSm;
            _ensureRowLayout(
              text: text,
              wrapWidth: math.max(1.0, textAreaWidth - _caretMargin),
              style: textStyle,
            );
            final rowStarts = _rowStarts;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LineNumberGutter(
                  scheme: scheme,
                  lineHeight: _lineHeight,
                  fontSize: widget.fontSize,
                  width: gutterWidth,
                  rowStarts: rowStarts,
                  currentLine: currentLine,
                  scrollOffset: scrollOffset,
                  viewportHeight: viewportHeight,
                ),
                Container(
                    width: 0.5,
                    color: scheme.gutterText.withValues(alpha: 0.15)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final editorStack = Stack(
                        children: [
                          _ErrorLineHighlight(
                            scheme: scheme,
                            lineHeight: _lineHeight,
                            errorLine: widget.controller.errorLine,
                            rowStarts: rowStarts,
                            scrollOffset: scrollOffset,
                          ),
                          _CurrentLineHighlight(
                            scheme: scheme,
                            lineHeight: _lineHeight,
                            currentLine: currentLine,
                            rowStarts: rowStarts,
                            scrollOffset: scrollOffset,
                            hasSelection: widget.controller.selection.isValid &&
                                widget.controller.selection.isCollapsed,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: AppConstants.spaceSm),
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
                              style: textStyle,
                              strutStyle: _strutStyle,
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

                      // Word wrap off: fixed width wide enough for the
                      // widest line, inside a horizontal scroll view.
                      // The width is MEASURED (not estimated): if it came
                      // out even a few pixels too small, the TextField
                      // would wrap the tail of the longest line onto an
                      // extra row and push every gutter number below it
                      // out of alignment. The gutter stays outside, so
                      // line numbers remain visible while code scrolls.
                      final contentWidth = math.max(
                        _maxLineWidth + AppConstants.spaceSm + _caretMargin + 8,
                        constraints.maxWidth,
                      );

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
            );
          },
        ),
      ),
    );
  }
}

class _LineNumberGutter extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final double fontSize;
  final double width;
  final List<int> rowStarts;
  final int currentLine;
  final double scrollOffset;
  final double? viewportHeight;

  const _LineNumberGutter({
    required this.scheme,
    required this.lineHeight,
    required this.fontSize,
    required this.width,
    required this.rowStarts,
    required this.currentLine,
    required this.scrollOffset,
    required this.viewportHeight,
  });

  @override
  Widget build(BuildContext context) {
    final lineCount = rowStarts.length - 1;

    // Largest line index whose first visual row is <= [row].
    int lineAtRow(int row) {
      var lo = 0;
      var hi = lineCount - 1;
      while (lo < hi) {
        final mid = (lo + hi + 1) >> 1;
        if (rowStarts[mid] <= row) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      return lo;
    }

    // Only lines near the visible viewport are built.
    int firstVisible;
    int lastVisible;
    if (viewportHeight == null) {
      // No layout measurement yet (first frame) — render everything once.
      firstVisible = 0;
      lastVisible = lineCount - 1;
    } else {
      const buffer = 4; // extra lines so fast flings don't show a blank edge
      final topRow = (scrollOffset / lineHeight).floor();
      final bottomRow = ((scrollOffset + viewportHeight!) / lineHeight).ceil();
      firstVisible = (lineAtRow(topRow) - buffer).clamp(0, lineCount - 1);
      lastVisible = (lineAtRow(bottomRow) + buffer).clamp(0, lineCount - 1);
    }

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: scheme.gutterBackground,
        child: Stack(
          children: [
            for (var i = firstVisible; i <= lastVisible; i++)
              Positioned(
                // The number sits on the FIRST visual row of its line,
                // so wrapped continuation rows get no number.
                top: (rowStarts[i] * lineHeight) - scrollOffset,
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
                        color:
                            i == currentLine ? scheme.text : scheme.gutterText,
                        fontWeight: i == currentLine
                            ? FontWeight.w600
                            : FontWeight.normal,
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

class _ErrorLineHighlight extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final int? errorLine;
  final List<int> rowStarts;
  final double scrollOffset;

  const _ErrorLineHighlight({
    required this.scheme,
    required this.lineHeight,
    required this.errorLine,
    required this.rowStarts,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    final line = errorLine;
    if (line == null || line < 1) return const SizedBox.shrink();

    final index = line - 1; // errorLine is 1-indexed
    if (index >= rowStarts.length - 1) return const SizedBox.shrink();

    final rows = rowStarts[index + 1] - rowStarts[index];
    return Positioned(
      top: (rowStarts[index] * lineHeight) - scrollOffset,
      left: 0,
      right: 0,
      height: rows * lineHeight,
      child: IgnorePointer(
        child:
            ColoredBox(color: const Color(0xFFE06C75).withValues(alpha: 0.18)),
      ),
    );
  }
}

class _CurrentLineHighlight extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final int currentLine;
  final List<int> rowStarts;
  final double scrollOffset;
  final bool hasSelection;

  const _CurrentLineHighlight({
    required this.scheme,
    required this.lineHeight,
    required this.currentLine,
    required this.rowStarts,
    required this.scrollOffset,
    required this.hasSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSelection || currentLine < 0) return const SizedBox.shrink();
    if (currentLine >= rowStarts.length - 1) return const SizedBox.shrink();

    final rows = rowStarts[currentLine + 1] - rowStarts[currentLine];
    return Positioned(
      top: (rowStarts[currentLine] * lineHeight) - scrollOffset,
      left: 0,
      right: 0,
      height: rows * lineHeight,
      child: IgnorePointer(
        child: ColoredBox(color: scheme.currentLine),
      ),
    );
  }
}
