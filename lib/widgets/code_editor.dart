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
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _lineCountOf(String text) => '\n'.allMatches(text).length + 1;

  double _gutterWidthFor(int lineCount) {
    final digits = lineCount.toString().length;
    return (digits * widget.fontSize * 0.62) + AppConstants.spaceMd + AppConstants.spaceXs;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.controller.scheme;

    return ColoredBox(
      color: scheme.background,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final gutterWidth = _gutterWidthFor(_lineCountOf(widget.controller.text));
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LineNumberGutter(
                controller: widget.controller,
                scrollController: _scrollController,
                scheme: scheme,
                lineHeight: _lineHeight,
                fontSize: widget.fontSize,
                width: gutterWidth,
              ),
              Container(width: 0.5, color: scheme.gutterText.withValues(alpha: 0.15)),
              Expanded(
                child: Stack(
                  children: [
                    _CurrentLineHighlight(
                      controller: widget.controller,
                      scrollController: _scrollController,
                      scheme: scheme,
                      lineHeight: _lineHeight,
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
                        // Without this, each line's actual rendered
                        // height comes from the font's own ascent/
                        // descent metrics, which don't exactly match
                        // fontSize*editorLineHeight — the gutter's
                        // assumed line height. That mismatch is small
                        // per line but compounds down the file, which
                        // is exactly the "line numbers drift out of
                        // sync" symptom. forceStrutHeight pins every
                        // line to precisely this height instead.
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
          );
        },
      ),
    );
  }
}

class _LineNumberGutter extends StatelessWidget {
  final CodeEditorController controller;
  final ScrollController scrollController;
  final EditorColorScheme scheme;
  final double lineHeight;
  final double fontSize;
  final double width;

  const _LineNumberGutter({
    required this.controller,
    required this.scrollController,
    required this.scheme,
    required this.lineHeight,
    required this.fontSize,
    required this.width,
  });

  int _currentLineIndex() {
    final offset = controller.selection.baseOffset;
    if (offset < 0) return -1;
    final clamped = offset.clamp(0, controller.text.length);
    return '\n'.allMatches(controller.text.substring(0, clamped)).length;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, scrollController]),
      builder: (context, _) {
        final lineCount = '\n'.allMatches(controller.text).length + 1;
        final offset = scrollController.hasClients ? scrollController.offset : 0.0;
        final currentLine = _currentLineIndex();

        // Each line number is absolutely positioned inside a Stack
        // rather than stacked in a Column. A Column asserts (and
        // overflows, as reported) whenever its children's combined
        // height exceeds what its parent hands it — which happens for
        // any file with more lines than fit on screen. A Stack has no
        // such assertion: children beyond its bounds are simply
        // clipped (Stack's default clipBehavior is Clip.hardEdge), so
        // this works regardless of file length or scroll position.
        return SizedBox(
          width: width,
          child: ColoredBox(
            color: scheme.gutterBackground,
            child: Stack(
              children: List.generate(lineCount, (i) {
                final isCurrent = i == currentLine;
                return Positioned(
                  top: (i * lineHeight) - offset,
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
      },
    );
  }
}

class _CurrentLineHighlight extends StatelessWidget {
  final CodeEditorController controller;
  final ScrollController scrollController;
  final EditorColorScheme scheme;
  final double lineHeight;

  const _CurrentLineHighlight({
    required this.controller,
    required this.scrollController,
    required this.scheme,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, scrollController]),
      builder: (context, _) {
        if (!controller.selection.isValid || !controller.selection.isCollapsed) {
          return const SizedBox.shrink();
        }
        final offset = controller.selection.baseOffset;
        final clamped = offset.clamp(0, controller.text.length);
        final lineIndex = '\n'.allMatches(controller.text.substring(0, clamped)).length;
        final scrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
        final top = (lineIndex * lineHeight) - scrollOffset;

        return Positioned(
          top: top,
          left: 0,
          right: 0,
          height: lineHeight,
          child: IgnorePointer(
            child: ColoredBox(color: scheme.currentLine),
          ),
        );
      },
    );
  }
}
