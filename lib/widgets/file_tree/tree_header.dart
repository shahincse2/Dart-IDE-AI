import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project_model.dart';
import '../../providers/file_provider.dart';
import '../../utils/constants.dart';
import '../name_dialog.dart';
import 'import_action.dart';
import 'tree_helpers.dart';

/// The top of the file tree: the project name and the buttons that add
/// things at the project root.
class TreeHeader extends StatelessWidget {
  final ProjectModel? project;

  const TreeHeader({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final open = project != null;
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
            onPressed: open ? () => _createAtRoot(context, isFolder: false) : null,
          ),
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            onPressed: open ? () => _createAtRoot(context, isFolder: true) : null,
          ),
          IconButton(
            tooltip: 'Import file',
            icon: const Icon(Icons.file_upload_outlined, size: 20),
            onPressed: open ? () => importFileInto(context, '') : null,
          ),
        ],
      ),
    );
  }

  Future<void> _createAtRoot(BuildContext context,
      {required bool isFolder}) async {
    final fileProvider = context.read<FileProvider>();
    final name = await showNameDialog(
      context,
      title: isFolder ? 'New folder' : 'New file',
      hint: isFolder ? 'Folder name' : 'File name',
    );
    if (name == null || name.isEmpty) return;
    if (isFolder) {
      await fileProvider.createFolder('', name);
    } else {
      await fileProvider.createFile('', name);
      // The new file is open in the editor now: get the drawer out of the way.
      if (context.mounted) closeDrawerIfOpen(context);
    }
  }
}
