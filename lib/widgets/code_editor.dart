import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/fold_regions.dart';
import 'code_editor/cursor_visibility.dart';
import 'code_editor/editor_surface.dart';
import 'code_editor/editor_text_style.dart';
import 'code_editor/line_layout.dart';
import 'code_editor_controller.dart';

/// The editing surface itself: a line-number gutter kept in lockstep with the
/// text via a shared [ScrollController], a subtle current-line highlight, and
/// the text field wired to [CodeEditorController] for highlighting,
/// bracket-matching and auto-indent.
///
/// This widget owns what must outlive a rebuild: the scroll position, the
/// focus, and the measured [LineLayout]. What is drawn is `EditorSurface`.
///
/// Gutter alignment: system text scaling is switched off for the whole editor
/// area so the gutter's fixed line height matches the TextField's rows, and
/// every line's vertical position comes from [LineLayout.lineTops] (measured
/// rows per line, with word wrap and folds) — not from `lineIndex * height`.
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
  final LineLayout _layout = LineLayout();

  List<FoldRegion>? _regionsSrc;
  Map<int, FoldRegion> _regionByStart = const {};

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
      // Switching to a different file's controller: start scrolled to the
      // top. The cursor/selection lives on the controller, so TextField picks
      // it up automatically.
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

  /// The user scrolled — just redraw the gutter/highlights to track the new
  /// offset. Deliberately does NOT scroll the cursor into view.
  void _onScrollChanged() {
    setState(() {});
  }

  void _ensureCursorVisible() {
    if (!mounted) return;
    scrollCursorIntoView(
      controller: widget.controller,
      scroll: _scrollController,
      layout: _layout,
      wordWrap: widget.wordWrap,
      lineHeight: editorLineHeight(widget.fontSize),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regions = widget.controller.foldRegions;
    if (!identical(_regionsSrc, regions)) {
      _regionsSrc = regions;
      _regionByStart = {for (final r in regions) r.startLine: r};
    }
    return EditorSurface(
      controller: widget.controller,
      layout: _layout,
      scrollController: _scrollController,
      focusNode: _focusNode,
      undoController: widget.undoController,
      fontSize: widget.fontSize,
      wordWrap: widget.wordWrap,
      regionByStart: _regionByStart,
    );
  }
}
