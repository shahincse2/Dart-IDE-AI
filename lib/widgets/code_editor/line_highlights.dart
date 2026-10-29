import 'package:flutter/material.dart';

import '../../utils/themes.dart';

/// Paints the row(s) of the line a runtime/syntax error was reported on.
class ErrorLineHighlight extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final int? errorLine;
  final List<double> lineTops;
  final double scrollOffset;

  const ErrorLineHighlight({
    super.key,
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

/// Paints the row(s) of the line the cursor is on.
class CurrentLineHighlight extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final int currentLine;
  final List<double> lineTops;
  final double scrollOffset;
  final bool hasSelection;

  const CurrentLineHighlight({
    super.key,
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
