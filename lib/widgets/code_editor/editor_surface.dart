import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/fold_regions.dart';
import '../code_editor_controller.dart';
import 'editor_text_area.dart';
import 'editor_text_style.dart';
import 'fold_chips.dart';
import 'line_layout.dart';
import 'line_number_gutter.dart';

/// The editor drawn: the line-number gutter, a thin divider and the text area,
/// laid out from the measured [LineLayout]. Rebuilt by [CodeEditor] whenever
/// the text, the selection, the folds or the scroll position change.
class EditorSurface extends StatelessWidget {
  final CodeEditorController controller;
  final LineLayout layout;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final UndoHistoryController? undoController;
  final double fontSize;
  final bool wordWrap;
  final Map<int, FoldRegion> regionByStart;

  const EditorSurface({
    super.key,
    required this.controller,
    required this.layout,
    required this.scrollController,
    required this.focusNode,
    required this.undoController,
    required this.fontSize,
    required this.wordWrap,
    required this.regionByStart,
  });

  /// Space the text layout keeps free at the right of the wrapping width.
  static const double caretMargin = 3.0;

  /// Width reserved at the left of the gutter for the fold chevron.
  static const double chevronWidth = 16.0;

  int _currentLine() {
    final offset = controller.selection.baseOffset;
    if (offset < 0) return -1;
    final text = controller.text;
    return '\n'.allMatches(text.substring(0, offset.clamp(0, text.length))).length;
  }

  double _gutterWidth(int lineCount) {
    final digits = lineCount.toString().length;
    return (digits * fontSize * 0.62) +
        AppConstants.spaceMd +
        AppConstants.spaceXs +
        chevronWidth;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = controller.scheme;
    final text = controller.text;
    final lineHeight = editorLineHeight(fontSize);
    final currentLine = _currentLine();
    final scrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
    final gutterWidth = _gutterWidth('\n'.allMatches(text).length + 1);
    final textStyle = editorTextStyle(context, scheme, fontSize);
    final strut = editorStrutStyle(fontSize);
    final hiddenLines = controller.hiddenLineRanges;

    return MediaQuery.withNoTextScaling(
      child: ColoredBox(
        color: scheme.background,
        child: LayoutBuilder(
          builder: (context, outer) {
            // gutter + 0.5px divider + left padding of the text field
            final textAreaWidth =
                outer.maxWidth - gutterWidth - 0.5 - AppConstants.spaceSm;
            layout.ensure(
              text: text,
              wrapWidth: math.max(1.0, textAreaWidth - caretMargin),
              style: textStyle,
              fontSize: fontSize,
              lineHeight: lineHeight,
              strut: strut,
              wordWrap: wordWrap,
              hiddenLines: hiddenLines,
              hiddenSig: controller.hiddenSignature,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LineNumberGutter(
                  scheme: scheme,
                  lineHeight: lineHeight,
                  fontSize: fontSize,
                  width: gutterWidth,
                  chevronWidth: chevronWidth,
                  lineTops: layout.lineTops,
                  hiddenLines: hiddenLines,
                  currentLine: currentLine,
                  scrollOffset: scrollOffset,
                  // The CURRENT height of the editor area. (Reading the scroll
                  // position's viewportDimension here was stale after any
                  // layout change — keyboard, console panel — so numbers below
                  // the old height were never drawn.)
                  viewportHeight:
                      outer.maxHeight.isFinite ? outer.maxHeight : null,
                  regionByStart: regionByStart,
                  isFolded: controller.isFolded,
                  onToggleFold: controller.toggleFold,
                ),
                Container(
                    width: 0.5,
                    color: scheme.gutterText.withValues(alpha: 0.15)),
                Expanded(
                  child: EditorTextArea(
                    controller: controller,
                    scheme: scheme,
                    lineHeight: lineHeight,
                    currentLine: currentLine,
                    lineTops: layout.lineTops,
                    scrollOffset: scrollOffset,
                    scrollController: scrollController,
                    focusNode: focusNode,
                    undoController: undoController,
                    textStyle: textStyle,
                    strutStyle: strut,
                    wordWrap: wordWrap,
                    maxLineWidth: layout.maxLineWidth,
                    caretMargin: caretMargin,
                    chips: buildFoldChips(
                      controller: controller,
                      scheme: scheme,
                      layout: layout,
                      regionByStart: regionByStart,
                      hiddenLines: hiddenLines,
                      lineHeight: lineHeight,
                      scrollOffset: scrollOffset,
                    ),
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
