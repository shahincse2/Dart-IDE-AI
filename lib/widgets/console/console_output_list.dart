import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/console_event.dart';
import '../../providers/runner_provider.dart';
import '../../utils/constants.dart';
import '../../utils/themes.dart';
import 'console_line_builder.dart';
import 'console_metrics.dart';
import 'console_output_row.dart';
import 'pixel_row_splitter.dart';

/// The scrolling output area of the console.
///
/// Rows have a fixed height (`itemExtent`), so jumping to the newest line
/// or dragging the scrollbar through thousands of lines costs the same as
/// moving one row. Long text is cut into several rows by
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

  ConsoleMetrics? _metrics;

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

  /// Tells the builder how to cut rows for the current width. A short
  /// plain-ASCII line cannot be wider than "length x widest glyph", so it
  /// needs no measuring at all; everything else asks the text engine.
  void _configureBuilder(double width) {
    final metrics = _metrics ??= ConsoleMetrics.measure();
    final glyph = metrics.widestGlyph;
    final style = consoleTextStyle();
    final room = width -
        2 * AppConstants.spaceMd -
        kConsoleIconWidth -
        AppConstants.spaceSm;

    _builder.configure(
      layoutKey: room.round(),
      splitter: (text, type) {
        final available = math.max(
          glyph * 4,
          type == ConsoleEventType.stderr ? room - metrics.labelWidth : room,
        );
        if (isPlainAscii(text) && text.length * glyph <= available) {
          return [text];
        }
        return splitByPixels(text, style, available);
      },
    );
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
          _configureBuilder(constraints.maxWidth);
          // Decided before the new rows are laid out: a user who scrolled
          // up to read earlier output is left where they are.
          final follow = _isNearBottom;
          final before = _builder.lines.length;
          _builder.update(events);
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
            itemBuilder: (context, i) => ConsoleOutputRow(
              line: lines[i],
              scheme: widget.scheme,
              labelWidth: _metrics!.labelWidth,
            ),
          );
        },
      ),
    );
  }
}
