import '../providers/file_provider.dart';
import '../utils/project_tree.dart';
import 'open_files_store.dart';

/// After a project has been opened (which opens its default file), brings
/// back the tabs the user had open last time, in the same order and with the
/// same one active. Files that no longer exist are skipped.
///
/// [remembered] must have been read BEFORE the project was opened, because
/// opening the default file changes what is remembered.
Future<void> restoreOpenFiles(FileProvider files, OpenFiles? remembered) async {
  if (remembered == null) return;
  final tabs = remembered.tabs
      .where((path) => treeContainsFile(files.fileTree, path))
      .toList();
  if (tabs.isEmpty) return;

  // Close the default tab first, so the remembered order is the real order.
  for (final path in List<String>.of(files.openTabs)) {
    await files.closeTab(path, flush: true);
  }
  for (final path in tabs) {
    files.openFile(path);
  }
  final active = remembered.active;
  files.openFile(active != null && tabs.contains(active) ? active : tabs.last);
}
