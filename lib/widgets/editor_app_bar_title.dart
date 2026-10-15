import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// The title of the editor's app bar: the file name (with a dot while it has
/// unsaved changes) and, in small text below it, where the file lives.
class EditorAppBarTitle extends StatelessWidget {
  const EditorAppBarTitle({
    super.key,
    required this.fileName,
    required this.filePath,
    required this.isDirty,
  });

  final String fileName;
  final String? filePath;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = filePath;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(fileName, overflow: TextOverflow.ellipsis)),
            if (isDirty) ...[
              const SizedBox(width: AppConstants.spaceSm),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        if (path != null)
          Text(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
