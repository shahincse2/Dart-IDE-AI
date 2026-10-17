import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../providers/tree_selection_provider.dart';
import '../utils/constants.dart';
import 'file_tree/file_tree_entry.dart';
import 'file_tree/selection_header.dart';
import 'file_tree/transfer_action.dart';
import 'file_tree/tree_header.dart';

/// The real file tree (Section 21), replacing the drawer's
/// "File tree arrives in Phase 5" placeholder. Reads [FileProvider]
/// directly rather than taking it as a constructor param, same pattern
/// as [ConsolePanel] — this widget is meant to be dropped into the
/// drawer/sidebar as-is. The rows and actions live in `file_tree/`.
class FileTreeView extends StatelessWidget {
  const FileTreeView({super.key});

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileProvider>();
    final selection = context.watch<TreeSelection>();
    final project = fileProvider.currentProject;
    final tree = fileProvider.fileTree;
    final selecting = selection.isActive(project?.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selecting)
          SelectionHeader(
            count: selection.countFor(project?.id),
            onClose: selection.clear,
            onCopy: () => _transferSelection(context, copy: true),
            onMove: () => _transferSelection(context, copy: false),
          )
        else
          TreeHeader(project: project),
        const Divider(height: 0.5),
        Expanded(
          child: project == null
              ? const _EmptyState(message: 'No project open yet.')
              : RefreshIndicator(
                  onRefresh: fileProvider.refreshFileTree,
                  child: tree == null
                      ? const Center(child: CircularProgressIndicator())
                      : tree.children.isEmpty
                          ? ListView(
                              // A scrollable ancestor is required for
                              // RefreshIndicator's pull gesture to work
                              // even when there's nothing to show yet.
                              children: const [
                                _EmptyState(
                                  message:
                                      'This project has no files yet.\nTap + above to add one.',
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppConstants.spaceSm),
                              children: tree.children
                                  .map((child) => FileTreeEntry(
                                        key: ValueKey(child.relativePath),
                                        node: child,
                                        depth: 0,
                                      ))
                                  .toList(),
                            ),
                ),
        ),
      ],
    );
  }
}

void _transferSelection(BuildContext context, {required bool copy}) {
  final files = context.read<FileProvider>();
  final entries =
      context.read<TreeSelection>().entriesFor(files.currentProject?.id);
  transferWithDialog(context, files, entries, copy: copy);
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13),
        ),
      ),
    );
  }
}
