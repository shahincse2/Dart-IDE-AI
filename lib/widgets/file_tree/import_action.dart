import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/file_provider.dart';
import '../../providers/folder_focus_provider.dart';
import '../../services/file_share_service.dart';
import 'tree_helpers.dart';

/// Lets the user pick a .dart file from the device and adds it to
/// [folder] of the current project (`` is the project root), then opens it.
Future<void> importFileInto(
  BuildContext context,
  String folder, {
  FileShareService? service,
}) async {
  final files = context.read<FileProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final picked = await (service ?? FileShareService()).importDartFile();
  if (picked == null) return;

  await files.importFile(picked.name, picked.content, parentRelativePath: folder);
  final where = folder.isEmpty ? 'the project root' : folder;
  messenger.showSnackBar(SnackBar(content: Text('Imported into $where')));
  if (context.mounted) closeDrawerIfOpen(context);
}

/// Import from the app menu: into the folder last tapped in the file tree,
/// or, if none counts, the folder of the file being edited.
Future<void> importIntoCurrentFolder(
  BuildContext context, {
  FileShareService? service,
}) {
  final files = context.read<FileProvider>();
  final focus = context.read<FolderFocus>();
  final folder = focus.folderFor(files.currentProject?.id, files.activeTab) ??
      files.activeFolder;
  return importFileInto(context, folder, service: service);
}
