import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/themes.dart';
import '../code_editor_controller.dart';
import 'line_highlights.dart';
import 'scroll_offset.dart';

/// The text itself: the error-line and current-line highlights behind the
/// TextField, and the fold chips on top. With word wrap off the whole thing
/// is as wide as the widest line, inside a horizontal scroll view.
class EditorTextArea extends StatelessWidget {
  final CodeEditorController controller;
  final EditorColorScheme scheme;
  final double lineHeight;
  final int currentLine;
  final List<double> lineTops;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final UndoHistoryController? undoController;
  final TextStyle textStyle;
  final StrutStyle strutStyle;
  /// The fold chips for a given scroll offset.
  final List<Widget> Function(double scrollOffset) chipsAt;
  final bool wordWrap;
  final double maxLineWidth;

  /// Flutter's text layout reserves `cursorWidth + 1px gap` on the right of
  /// the wrapping width. cursorWidth is 2 below.
  final double caretMargin;

  const EditorTextArea({
    super.key,
    required this.controller,
    required this.scheme,
    required this.lineHeight,
    required this.currentLine,
    required this.lineTops,
    required this.scrollController,
    required this.focusNode,
    required this.undoController,
    required this.textStyle,
    required this.strutStyle,
    required this.chipsAt,
    required this.wordWrap,
    required this.maxLineWidth,
    required this.caretMargin,
  });

  /// [build] is run again on every scroll tick, with the new offset, and
  /// nothing else is: the text field next to it stays as it is.
  Widget _followingScroll(Widget Function(double scrollOffset) build) {
    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, _) => build(scrollOffsetOf(scrollController)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final editorStack = Stack(
          children: [
            _followingScroll(
              (scrollOffset) => ErrorLineHighlight(
                scheme: scheme,
                lineHeight: lineHeight,
                errorLine: controller.errorLine,
                lineTops: lineTops,
                scrollOffset: scrollOffset,
              ),
            ),
            _followingScroll(
              (scrollOffset) => CurrentLineHighlight(
                scheme: scheme,
                lineHeight: lineHeight,
                currentLine: currentLine,
                lineTops: lineTops,
                scrollOffset: scrollOffset,
                hasSelection: controller.selection.isValid &&
                    controller.selection.isCollapsed,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: AppConstants.spaceSm),
              child: TextField(
                controller: controller,
                scrollController: scrollController,
                focusNode: focusNode,
                undoController: undoController,
                maxLines: null,
                expands: true,
                cursorColor: scheme.cursor,
                cursorWidth: 2,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: textStyle,
                strutStyle: strutStyle,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Positioned.fill(
              child: _followingScroll((scrollOffset) {
                final chips = chipsAt(scrollOffset);
                return chips.isEmpty
                    ? const SizedBox.shrink()
                    : Stack(clipBehavior: Clip.none, children: chips);
              }),
            ),
          ],
        );

        if (wordWrap) return editorStack;

        // Word wrap off: fixed width wide enough for the widest line, inside a
        // horizontal scroll view. The width is MEASURED (not estimated): if it
        // came out even a few pixels too small, the TextField would wrap the
        // tail of the longest line onto an extra row and push every gutter
        // number below it out of alignment.
        final contentWidth = (maxLineWidth +
                AppConstants.spaceSm +
                caretMargin +
                8)
            .clamp(constraints.maxWidth, double.infinity)
            .toDouble();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: editorStack,
          ),
        );
      },
    );
  }
}
