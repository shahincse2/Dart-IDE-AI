import 'package:flutter/material.dart';

import '../../utils/themes.dart';

/// The small "..." marker shown on the row of a folded block.
class FoldChip extends StatelessWidget {
  final EditorColorScheme scheme;
  final double lineHeight;
  final VoidCallback onTap;

  const FoldChip({
    super.key,
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
