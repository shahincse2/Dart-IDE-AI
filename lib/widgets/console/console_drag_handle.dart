import 'package:flutter/material.dart';

import '../../providers/console_provider.dart';
import '../../utils/constants.dart';

class ConsoleDragHandle extends StatelessWidget {
  final ConsoleProvider console;
  final double maxHeight;

  const ConsoleDragHandle({
    super.key,
    required this.console,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        console.setHeight(console.height - details.delta.dy,
            maxHeight: maxHeight);
      },
      child: SizedBox(
        height: AppConstants.consoleDragHandleHeight,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
