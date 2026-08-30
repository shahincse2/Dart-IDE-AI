import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_file_node.dart';
import '../models/project_model.dart';
import '../providers/file_provider.dart';
import '../utils/constants.dart';

/// The real file tree (Section 21), replacing the drawer's
/// "File tree arrives in Phase 5" placeholder. Reads [FileProvider]
/// directly rather than taking it as a constructor param, same pattern
/// as [ConsolePanel] — this widget is meant to be dropped into the
/// drawer/sidebar as-is.
class FileTreeView extends StatelessWidget {
  const FileTreeView({super.key});

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileProvider>();
    final project = fileProvider.currentProject;
    final tree = fileProvider.fileTree;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TreeHeader(project: project),
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
                                  message: 'This project has no files yet.\nTap + above to add one.',
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceSm),
                              children: tree.children
                                  .map((child) => _FileTreeEntry(
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

class _TreeHeader extends StatelessWidget {
  final ProjectModel? project;

  const _TreeHeader({required this.project});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        AppConstants.spaceMd,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              project?.name ?? AppConstants.appName,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'New file',
            icon: const Icon(Icons.note_add_outlined, size: 20),
            onPressed: project == null ? null : () => _createAtRoot(context, isFolder: false),
          ),
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            onPressed: project == null ? null : () => _createAtRoot(context, isFolder: true),
          ),
        ],
      ),
    );
  }

  Future<void> _createAtRoot(BuildContext context, {required bool isFolder}) async {
    final fileProvider = context.read<FileProvider>();
    final name = await _promptForName(context, title: isFolder ? 'New folder' : 'New file');
    if (name == null || name.isEmpty) return;
    if (isFolder) {
      await fileProvider.createFolder('', name);
    } else {
      await fileProvider.createFile('', name);
    }
  }
}

class _FileTreeEntry extends StatefulWidget {
  final ProjectFileNode node;
  final int depth;

  const _FileTreeEntry({super.key, required this.node, required this.depth});

  @override
  State<_FileTreeEntry> createState() => _FileTreeEntryState();
}

class _FileTreeEntryState extends State<_FileTreeEntry> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final fileProvider = context.watch<FileProvider>();

    if (node.isFile) {
      final isOpen = fileProvider.openFileRelativePath == node.relativePath;
      return _EntryRow(
        icon: Icons.description_outlined,
        label: node.name,
        depth: widget.depth,
        selected: isOpen,
        onTap: () => fileProvider.openFile(node.relativePath),
        onLongPress: () => _showEntryActions(context, node, isFolder: false),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EntryRow(
          icon: _expanded ? Icons.folder_open_outlined : Icons.folder_outlined,
          trailingIcon: _expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
          label: node.name,
          depth: widget.depth,
          onTap: () => setState(() => _expanded = !_expanded),
          onLongPress: () => _showEntryActions(context, node, isFolder: true),
        ),
        if (_expanded)
          ...node.children.map(
            (child) => _FileTreeEntry(
              key: ValueKey(child.relativePath),
              node: child,
              depth: widget.depth + 1,
            ),
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final IconData icon;
  final IconData? trailingIcon;
  final String label;
  final int depth;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _EntryRow({
    required this.icon,
    this.trailingIcon,
    required this.label,
    required this.depth,
    this.selected = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer.withOpacity(0.4) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppConstants.spaceMd + depth * AppConstants.spaceLg,
            right: AppConstants.spaceMd,
            top: AppConstants.spaceSm,
            bottom: AppConstants.spaceSm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              if (trailingIcon != null) Icon(trailingIcon, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      ),
    );
  }
}

// ---- Shared prompts (used by both the header's + buttons and the
// long-press menu below) ----

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDelete(BuildContext context, String name) {
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

Future<void> _showEntryActions(
  BuildContext context,
  ProjectFileNode node, {
  required bool isFolder,
}) async {
  final fileProvider = context.read<FileProvider>();

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFolder) ...[
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('New file here'),
              onTap: () => Navigator.pop(sheetContext, 'new_file'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder here'),
              onTap: () => Navigator.pop(sheetContext, 'new_folder'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Rename'),
            onTap: () => Navigator.pop(sheetContext, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete'),
            onTap: () => Navigator.pop(sheetContext, 'delete'),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted || action == null) return;

  switch (action) {
    case 'new_file':
      final name = await _promptForName(context, title: 'New file');
      if (name != null && name.isNotEmpty) {
        await fileProvider.createFile(node.relativePath, name);
      }
    case 'new_folder':
      final name = await _promptForName(context, title: 'New folder');
      if (name != null && name.isNotEmpty) {
        await fileProvider.createFolder(node.relativePath, name);
      }
    case 'rename':
      final name = await _promptForName(context, title: 'Rename', initialValue: node.name);
      if (name != null && name.isNotEmpty && name != node.name) {
        await fileProvider.renameEntry(node.relativePath, name, isFolder: isFolder);
      }
    case 'delete':
      if (!context.mounted) return;
      final confirmed = await _confirmDelete(context, node.name);
      if (confirmed == true) {
        await fileProvider.deleteEntry(node.relativePath, isFolder: isFolder);
      }
  }
}
