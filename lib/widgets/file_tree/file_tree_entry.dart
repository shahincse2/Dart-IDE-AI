import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project_file_node.dart';
import '../../models/tree_entry_ref.dart';
import '../../providers/file_provider.dart';
import '../../providers/folder_expansion_provider.dart';
import '../../providers/folder_focus_provider.dart';
import '../../providers/tree_selection_provider.dart';
import 'entry_actions.dart';
import 'entry_row.dart';
import 'tree_helpers.dart';

/// One row of the file tree, and, for a folder that is open, its children.
///
/// Normally a tap opens a file or opens/closes a folder. While several
/// entries are being selected, a tap ticks or unticks the row instead (a
/// folder's arrow still opens and closes it).
class FileTreeEntry extends StatelessWidget {
  final ProjectFileNode node;
  final int depth;

  const FileTreeEntry({super.key, required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    final files = context.watch<FileProvider>();
    final selection = context.watch<TreeSelection>();
    final projectId = files.currentProject?.id;
    final selecting = selection.isActive(projectId);
    final ref = TreeEntryRef(node.relativePath, isFolder: node.isFolder);
    final checked = selecting ? selection.isSelected(projectId, ref.path) : null;
    void toggleSelection() => selection.toggle(ref);

    if (node.isFile) {
      final isOpen = files.openTabs.contains(node.relativePath);
      final isActive = files.activeTab == node.relativePath;
      return EntryRow(
        icon: Icons.description_outlined,
        label: node.name,
        depth: depth,
        selected: isActive,
        checked: checked,
        // Files that are open in a background tab (but not the active
        // one) get a lighter indicator than the fully-selected style.
        openIndicator: isOpen && !isActive,
        onTap: selecting
            ? toggleSelection
            : () {
                files.openFile(node.relativePath);
                closeDrawerIfOpen(context);
              },
        onLongPress: selecting
            ? toggleSelection
            : () => showEntryActions(context, node, isFolder: false),
      );
    }

    // Whether a folder is open is kept in FolderExpansion, not here: this
    // widget is rebuilt (and the whole tree even moves between drawer and
    // sidebar), and a folder the user closed must stay closed.
    final folderKey = '$projectId/${node.relativePath}';
    final expansion = context.read<FolderExpansion>();
    final expanded = context
        .select<FolderExpansion, bool>((state) => state.isExpanded(folderKey));
    final focused = context.select<FolderFocus, bool>(
        (focus) => focus.folderFor(projectId, files.activeTab) == node.relativePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntryRow(
          icon: expanded ? Icons.folder_open_outlined : Icons.folder_outlined,
          trailingIcon: expanded
              ? Icons.expand_more_rounded
              : Icons.chevron_right_rounded,
          onTrailingTap: selecting ? () => expansion.toggle(folderKey) : null,
          label: node.name,
          depth: depth,
          selected: focused,
          checked: checked,
          onTap: selecting
              ? toggleSelection
              : () {
                  expansion.toggle(folderKey);
                  context
                      .read<FolderFocus>()
                      .focus(projectId, node.relativePath, files.activeTab);
                },
          onLongPress: selecting
              ? toggleSelection
              : () => showEntryActions(context, node, isFolder: true),
        ),
        if (expanded)
          ...node.children.map(
            (child) => FileTreeEntry(
              key: ValueKey(child.relativePath),
              node: child,
              depth: depth + 1,
            ),
          ),
      ],
    );
  }
}
