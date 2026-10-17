import 'package:flutter/material.dart';

/// Picking (or creating) a file closes the drawer. On wide screens the tree
/// is a sidebar: there is no drawer, so there is nothing to close.
void closeDrawerIfOpen(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
}

Future<bool?> confirmDelete(BuildContext context, String name) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete'),
      content: Text('Delete "$name"? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
