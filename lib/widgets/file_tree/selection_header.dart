import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// The top of the file tree while several entries are being selected: how
/// many are ticked, and what to do with them.
class SelectionHeader extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback onMove;

  const SelectionHeader({
    super.key,
    required this.count,
    required this.onClose,
    required this.onCopy,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceSm,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Stop selecting',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              '$count selected',
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Copy to…',
            icon: const Icon(Icons.copy_outlined, size: 20),
            onPressed: onCopy,
          ),
          IconButton(
            tooltip: 'Move to…',
            icon: const Icon(Icons.drive_file_move_outlined, size: 20),
            onPressed: onMove,
          ),
        ],
      ),
    );
  }
}
