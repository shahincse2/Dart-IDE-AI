import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/fold_regions.dart';
import '../utils/themes.dart';
import 'code_editor_controller.dart';

/// The editing surface itself: a line-number gutter kept in lockstep
/// with the text via a shared [ScrollController], a subtle current-line
/// highlight, and the text field wired to [CodeEditorController] for
/// highlighting/bracket-matching/auto-indent.
///
/// Gutter alignment:
///  * System text scaling is switched off for the whole editor area
///    (`MediaQuery.withNoTextScaling`) so the gutter's fixed line height
///    matches the TextField's rows.
///  * Every line's vertical position comes from `_lineTops`, computed by
///    measuring how many visual rows each logical line takes (word wrap)
///    — not from `lineIndex * lineHeight`.
///
/// Code folding (Phase 11):
///  * Foldable lines get a chevron in the gutter; tapping the chevron or
///    the line number folds/unfolds.
///  * A folded block shows as ONE placeholder row between the opening and
///    the closing line, with a small "..." chip indented like the folded
///    code (tap the chip, or the row, to unfold):
///        for (...) {
///            [...]
///        }
///    The folded lines stay in the text; the controller draws them as
///    zero-width characters with a single line break at the end. In
///    `_lineTops` the first hidden line owns that one placeholder row and
///    the rest of the hidden lines are 0px tall.
///  * The forced strut stays on at all times, so line heights are the
///    same with or without folds.
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

  /// Width reserved at the left of the gutter for the fold chevron.
  static const double _chevronWidth = 16.0;

  // ---- Layout cache -----------------------------------------------------
  final Map<String, int> _lineRowsCache = {};
  final Map<String, double> _lineWidthCache = {};

  /// Natural width of the widest visible line (word wrap OFF only).
  double _maxLineWidth = 0;

  /// `_lineTops[i]` = y (px) of the top of logical line i.
  /// `_lineTops.last` = total content height. Length = lineCount + 1.
  List<double> _lineTops = const [0.0];
  List<String> _lines = const [''];

  String? _layoutText;
  double _layoutWidth = -1;
  double _layoutFontSize = -1;
  bool _layoutWrap = true;
  String _layoutHiddenSig = '';
  TextStyle? _measureStyle;
  double _measureWidth = 1;
  double _charWidth = 0;

  List<FoldRegion>? _regionsSrc;
  Map<int, FoldRegion> _regionByStart = const {};

  double get _lineHeight => widget.fontSize * AppConstants.editorLineHeight;

  /// Forced strut: every visual row is exactly one line tall.
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

  /// Text, selection or fold state changed — redraw, and auto-scroll the
  /// cursor into view.
  void _onControllerChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCursorVisible());
  }

  /// The user scrolled — just redraw the gutter/highlights to track the
  /// new offset. Deliberately does NOT call `_ensureCursorVisible`.
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

    if (lineIndex >= _lineTops.length - 1) return;

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

    final lineTop = _lineTops[lineIndex] + rowInLine * _lineHeight;
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
        AppConstants.spaceXs +
        _chevronWidth;
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

  static bool _isLineHidden(int line, List<LineRange> ranges) {
    for (final r in ranges) {
      if (line >= r.first && line <= r.last) return true;
      if (r.first > line) break;
    }
    return false;
  }

  /// Exact unwrapped width of one line (used for the fold chip, which
  /// only exists for a handful of lines, so measuring is cheap).
  double _measureLineWidth(String line) {
    if (line.isEmpty) return 0;
    final tp = TextPainter(
      text: TextSpan(text: line, style: _measureStyle),
      strutStyle: _strutStyle,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  /// Rebuilds [_lineTops] when the text, wrapping width, font size, wrap
  /// mode, style or fold state changed; otherwise returns immediately.
  void _ensureRowLayout({
    required String text,
    required double wrapWidth,
    required TextStyle style,
    required List<LineRange> hiddenLines,
    required String hiddenSig,
  }) {
    final wrap = widget.wordWrap;
    final measureUnchanged = _layoutWidth == wrapWidth &&
        _layoutFontSize == widget.fontSize &&
        _layoutWrap == wrap &&
        _measureStyle == style;
    if (measureUnchanged &&
        _layoutText == text &&
        _layoutHiddenSig == hiddenSig) {
      return;
    }

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
    _layoutHiddenSig = hiddenSig;
    if (!measureUnchanged) _charWidth = _measureCharWidth(style);

    final lines = text.split('\n');
    final tops = List<double>.filled(lines.length + 1, 0);
    var y = 0.0;
    var maxWidth = 0.0;
    var hr = 0; // pointer into hiddenLines (sorted)
    for (var i = 0; i < lines.length; i++) {
      while (hr < hiddenLines.length && hiddenLines[hr].last < i) {
        hr++;
      }
      final hidden = hr < hiddenLines.length && hiddenLines[hr].first <= i;

      tops[i] = y;
      if (hidden) {
        // The first hidden line of a range owns the single placeholder
        // row; the rest of the range adds no height.
        if (i == hiddenLines[hr].first) y += _lineHeight;
        continue;
      }
      if (wrap) {
        y += _rowsForLine(lines[i]) * _lineHeight;
      } else {
        y += _lineHeight;
        final w = _widthForLine(lines[i]);
        if (w > maxWidth) maxWidth = w;
      }
    }
    tops[lines.length] = y;
    _lines = lines;
    _lineTops = tops;
    _maxLineWidth = maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final scheme = ctrl.scheme;
    final text = ctrl.text;
    final lineCount = _lineCountOf(text);
    final currentLine = _currentLineIndex();
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final gutterWidth = _gutterWidthFor(lineCount);
    final textStyle = _editorTextStyle(context, scheme);

    final hiddenLines = ctrl.hiddenLineRanges;
    final hiddenSig = ctrl.hiddenSignature;

    final regions = ctrl.foldRegions;
    if (!identical(_regionsSrc, regions)) {
      _regionsSrc = regions;
      _regionByStart = {for (final r in regions) r.startLine: r};
    }

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
              hiddenLines: hiddenLines,
              hiddenSig: hiddenSig,
            );
            final lineTops = _lineTops;

            // One "..." chip per folded block, on its placeholder row
            // (the first hidden line), indented like the folded code.
            final chips = <Widget>[];
            for (final s in ctrl.foldedStartLines) {
              final region = _regionByStart[s];
              if (region == null) continue;
              if (_isLineHidden(s, hiddenLines)) {
                continue; // inside an outer fold
              }
              final p = s + 1; // placeholder row = first hidden line
              if (p + 1 >= lineTops.length || p >= _lines.length) continue;

              var indent = '';
              for (var l = p; l < region.endLine && l < _lines.length; l++) {
                final t = _lines[l];
                if (t.trim().isEmpty) continue;
                indent = t.substring(0, t.length - t.trimLeft().length);
                break;
              }
              final x = indent.isEmpty
                  ? 0.0
                  : _measureLineWidth('${indent}x') - _measureLineWidth('x');

              chips.add(
                Positioned(
                  left: AppConstants.spaceSm + x,
                  top: lineTops[p] - scrollOffset,
                  height: _lineHeight,
                  child: _FoldChip(
                    scheme: scheme,
                    lineHeight: _lineHeight,
                    onTap: () => ctrl.toggleFold(s),
                  ),
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LineNumberGutter(
                  scheme: scheme,
                  lineHeight: _lineHeight,
                  fontSize: widget.fontSize,
                  width: gutterWidth,
                  chevronWidth: _chevronWidth,
                  lineTops: lineTops,
                  hiddenLines: hiddenLines,
                  currentLine: currentLine,
                  scrollOffset: scrollOffset,
                  // The CURRENT height of the editor area. (Reading the
                  // scroll position's viewportDimension here was stale
                  // after any layout change — keyboard, console panel —
                  // so numbers below the old height were never drawn.)
                  viewportHeight:
                      outer.maxHeight.isFinite ? outer.maxHeight : null,
                  regionByStart: _regionByStart,
                  isFolded: ctrl.isFolded,
                  onToggleFold: ctrl.toggleFold,
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
                            errorLine: ctrl.errorLine,
                            lineTops: lineTops,
                            scrollOffset: scrollOffset,
                          ),
                          _CurrentLineHighlight(
                            scheme: scheme,
                            lineHeight: _lineHeight,
                            currentLine: currentLine,
                            lineTops: lineTops,
                            scrollOffset: scrollOffset,
                            hasSelection: ctrl.selection.isValid &&
                                ctrl.selection.isCollapsed,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: AppConstants.spaceSm),
                            child: TextField(
                              controller: ctrl,
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
                          ...chips,
                        ],
                      );

                      if (widget.wordWrap) return editorStack;

                      // Word wrap off: fixed width wide enough for the
                      // widest line, inside a horizontal scroll view.
                      // The width is MEASURED (not estimated): if it came
                      // out even a few pixels too small, the TextField
                      // would wrap the tail of the longest line onto an
                      // extra row and push every gutter number below it
                      // out of alignment.
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
  final double chevronWidth;
  final List<double> lineTops;
  final List<LineRange> hiddenLines;
  final int currentLine;
  final double scrollOffset;
  final double? viewportHeight;
  final Map<int, FoldRegion> regionByStart;
  final bool Function(int line) isFolded;
  final void Function(int line) onToggleFold;

  const _LineNumberGutter({
    required this.scheme,
    required this.lineHeight,
    required this.fontSize,
    required this.width,
    required this.chevronWidth,
    required this.lineTops,
    required this.hiddenLines,
    required this.currentLine,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.regionByStart,
    required this.isFolded,
    required this.onToggleFold,
  });

  @override
  Widget build(BuildContext context) {
    final lineCount = lineTops.length - 1;

    // Largest line index whose top is <= [y].
    int lineAtY(double y) {
      var lo = 0;
      var hi = lineCount - 1;
      while (lo < hi) {
        final mid = (lo + hi + 1) >> 1;
        if (lineTops[mid] <= y) {
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
      firstVisible = (lineAtY(scrollOffset) - buffer).clamp(0, lineCount - 1);
      lastVisible = (lineAtY(scrollOffset + viewportHeight!) + buffer)
          .clamp(0, lineCount - 1);
    }

    final children = <Widget>[];
    var hr = 0; // pointer into hiddenLines (sorted)
    while (hr < hiddenLines.length && hiddenLines[hr].last < firstVisible) {
      hr++;
    }
    for (var i = firstVisible; i <= lastVisible; i++) {
      while (hr < hiddenLines.length && hiddenLines[hr].last < i) {
        hr++;
      }
      if (hr < hiddenLines.length && hiddenLines[hr].first <= i) {
        continue; // hidden by a fold: no number
      }

      final region = regionByStart[i];
      final folded = region != null && isFolded(i);

      Widget row = Row(
        children: [
          SizedBox(
            width: chevronWidth,
            child: region == null
                ? null
                : Icon(
                    folded
                        ? Icons.chevron_right_rounded
                        : Icons.expand_more_rounded,
                    size: fontSize,
                    color: folded ? scheme.text : scheme.gutterText,
                  ),
          ),
          Expanded(
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
                    fontWeight:
                        i == currentLine ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      );

      if (region != null) {
        // The whole gutter row (chevron + number) is the tap target —
        // a 16px chevron alone is too small for a finger.
        row = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onToggleFold(i),
          child: row,
        );
      }

      children.add(
        Positioned(
          // The number sits on the FIRST visual row of its line, so
          // wrapped continuation rows get no number.
          top: lineTops[i] - scrollOffset,
          left: 0,
          right: 0,
          height: lineHeight,
          child: row,
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: scheme.gutterBackground,
        child: Stack(children: children),
      ),
    );
  }
}

/// The small "..." marker shown after a folded line.
class _FoldChip extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final VoidCallback onTap;

  const _FoldChip({
    required this.scheme,
    required this.lineHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: lineHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: scheme.selection.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                size: lineHeight * 0.6,
                color: scheme.text.withValues(alpha: 0.8),
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
  final List<double> lineTops;
  final double scrollOffset;

  const _ErrorLineHighlight({
    required this.scheme,
    required this.lineHeight,
    required this.errorLine,
    required this.lineTops,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    final line = errorLine;
    if (line == null || line < 1) return const SizedBox.shrink();

    final index = line - 1; // errorLine is 1-indexed
    if (index >= lineTops.length - 1) return const SizedBox.shrink();

    final height = lineTops[index + 1] - lineTops[index];
    if (height < lineHeight * 0.5) return const SizedBox.shrink();

    return Positioned(
      top: lineTops[index] - scrollOffset,
      left: 0,
      right: 0,
      height: height,
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
  final List<double> lineTops;
  final double scrollOffset;
  final bool hasSelection;

  const _CurrentLineHighlight({
    required this.scheme,
    required this.lineHeight,
    required this.currentLine,
    required this.lineTops,
    required this.scrollOffset,
    required this.hasSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSelection || currentLine < 0) return const SizedBox.shrink();
    if (currentLine >= lineTops.length - 1) return const SizedBox.shrink();

    final height = lineTops[currentLine + 1] - lineTops[currentLine];
    if (height < lineHeight * 0.5) return const SizedBox.shrink();

    return Positioned(
      top: lineTops[currentLine] - scrollOffset,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: ColoredBox(color: scheme.currentLine),
      ),
    );
  }
}
