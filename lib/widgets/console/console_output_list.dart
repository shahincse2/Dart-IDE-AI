import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../providers/runner_provider.dart';
import '../../utils/constants.dart';
import '../../utils/themes.dart';
import 'console_line_builder.dart';
import 'console_output_row.dart';

/// The scrolling output area of the console.
///
/// Rows have a fixed height (`itemExtent`), so jumping to the newest line
/// or dragging the scrollbar through thousands of lines costs the same as
/// moving one row. Long text is wrapped into several rows by
/// [ConsoleLineBuilder] to fit the current width.
class ConsoleOutputList extends StatefulWidget {
  const ConsoleOutputList({
    super.key,
    required this.runner,
    required this.scheme,
  });

  final RunnerProvider runner;
  final EditorColorScheme scheme;

  @override
  State<ConsoleOutputList> createState() => _ConsoleOutputListState();
}

class _ConsoleOutputListState extends State<ConsoleOutputList> {
  /// "At the bottom" tolerance in pixels.
  static const double _bottomTolerance = 48;

  final _scrollController = ScrollController();
  final _builder = ConsoleLineBuilder();
  double? _charWidth;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  double _measureCharWidth() {
    final painter = TextPainter(
      // (not const: editorFontFamily is not guaranteed to be a constant)
      text: TextSpan(
        text: 'MMMMMMMMMM',
        style: TextStyle(
            fontFamily: editorFontFamily, fontSize: kConsoleFontSize),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width / 10;
    painter.dispose();
    return width;
  }

  /// How many characters of text fit on one row.
  int _columnsFor(double width) {
    final charWidth = _charWidth ??= _measureCharWidth();
    final usable = width -
        2 * AppConstants.spaceMd -
        kConsoleIconWidth -
        AppConstants.spaceSm -
        kConsoleLabelChars * charWidth;
    return math.max(8, (usable / charWidth).floor());
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.runner.events;

    if (events.isEmpty) {
      _builder.reset();
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
          // Decided before the new rows are laid out: a user who scrolled
          // up to read earlier output is left where they are.
          final follow = _isNearBottom;
          final before = _builder.lines.length;
          _builder.update(events, columns: _columnsFor(constraints.maxWidth));
          final lines = _builder.lines;
          if (follow && lines.length != before) _scrollToBottom();

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceMd,
              vertical: AppConstants.spaceSm,
            ),
            itemExtent: kConsoleRowExtent,
            itemCount: lines.length,
            itemBuilder: (context, i) =>
                ConsoleOutputRow(line: lines[i], scheme: widget.scheme),
          );
        },
      ),
    );
  }
}
