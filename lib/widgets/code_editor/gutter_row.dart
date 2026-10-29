import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/themes.dart';

/// One row of the line-number column: the fold chevron (on a [foldable] line)
/// and the line number. On a foldable line the whole row is the tap target — a
/// 16px chevron alone is too small for a finger.
class GutterRow extends StatelessWidget {
  final int line;
  final EditorColorScheme scheme;
  final double fontSize;
  final double chevronWidth;
  final bool isCurrent;
  final bool foldable;
  final bool folded;
  final void Function(int line) onToggleFold;

  const GutterRow({
    super.key,
    required this.line,
    required this.scheme,
    required this.fontSize,
    required this.chevronWidth,
    required this.isCurrent,
    required this.foldable,
    required this.folded,
    required this.onToggleFold,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        SizedBox(
          width: chevronWidth,
          child: !foldable
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
                '${line + 1}',
                style: TextStyle(
                  fontFamily: editorFontFamily,
                  fontSize: fontSize * 0.85,
                  color: isCurrent ? scheme.text : scheme.gutterText,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (!foldable) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggleFold(line),
      child: row,
    );
  }
}
