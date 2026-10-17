import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project_file_node.dart';
import '../../models/tree_entry_ref.dart';
import '../../providers/file_provider.dart';
import '../../providers/tree_selection_provider.dart';
import '../name_dialog.dart';
import 'import_action.dart';
import 'transfer_action.dart';
import 'tree_helpers.dart';

/// What the long-press menu of a file or folder can do.
enum EntryAction {
  newFile,
  newFolder,
  importFile,
  select,
  copy,
  move,
  rename,
  delete,
}

/// The long-press menu of a tree entry, and what each choice does.
Future<void> showEntryActions(
  BuildContext context,
  ProjectFileNode node, {
  required bool isFolder,
}) async {
  final action = await showModalBottomSheet<EntryAction>(
    context: context,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFolder) ...const [
              _ActionTile(Icons.note_add_outlined, 'New file here', EntryAction.newFile),
              _ActionTile(Icons.create_new_folder_outlined, 'New folder here', EntryAction.newFolder),
              _ActionTile(Icons.file_upload_outlined, 'Import file here', EntryAction.importFile),
            ],
            const _ActionTile(Icons.checklist_rounded, 'Select several', EntryAction.select),
            const _ActionTile(Icons.copy_outlined, 'Copy to…', EntryAction.copy),
            const _ActionTile(Icons.drive_file_move_outlined, 'Move to…', EntryAction.move),
            const _ActionTile(Icons.drive_file_rename_outline, 'Rename', EntryAction.rename),
            const _ActionTile(Icons.delete_outline, 'Delete', EntryAction.delete),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  final files = context.read<FileProvider>();
  final ref = TreeEntryRef(node.relativePath, isFolder: isFolder);
  switch (action) {
    case EntryAction.newFile:
      return _newFile(context, files, node);
    case EntryAction.newFolder:
      return _newFolder(context, files, node);
    case EntryAction.importFile:
      return importFileInto(context, node.relativePath);
    case EntryAction.select:
      context.read<TreeSelection>().begin(files.currentProject?.id, ref);
      return;
    case EntryAction.copy:
      return transferWithDialog(context, files, [ref], copy: true);
    case EntryAction.move:
      return transferWithDialog(context, files, [ref], copy: false);
    case EntryAction.rename:
      return _rename(context, files, node, isFolder: isFolder);
    case EntryAction.delete:
      return _delete(context, files, node, isFolder: isFolder);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(this.icon, this.label, this.action);

  final IconData icon;
  final String label;
  final EntryAction action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(context, action),
    );
  }
}

Future<void> _newFile(
  BuildContext context,
  FileProvider files,
  ProjectFileNode node,
) async {
  final name = await showNameDialog(context, title: 'New file');
  if (name == null || name.isEmpty) return;
  await files.createFile(node.relativePath, name);
  // The new file is open in the editor now: get the drawer out of the way.
  if (context.mounted) closeDrawerIfOpen(context);
}

Future<void> _newFolder(
  BuildContext context,
  FileProvider files,
  ProjectFileNode node,
) async {
  final name = await showNameDialog(context, title: 'New folder');
  if (name == null || name.isEmpty) return;
  await files.createFolder(node.relativePath, name);
}

Future<void> _rename(
  BuildContext context,
  FileProvider files,
  ProjectFileNode node, {
  required bool isFolder,
}) async {
  final name = await showNameDialog(
    context,
    title: 'Rename',
    initialValue: node.name,
  );
  if (name == null || name.isEmpty || name == node.name) return;
  await files.renameEntry(node.relativePath, name, isFolder: isFolder);
}

Future<void> _delete(
  BuildContext context,
  FileProvider files,
  ProjectFileNode node, {
  required bool isFolder,
}) async {
  final confirmed = await confirmDelete(context, node.name);
  if (confirmed == true) {
    await files.deleteEntry(node.relativePath, isFolder: isFolder);
  }
}
