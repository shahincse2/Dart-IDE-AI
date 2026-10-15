import '../providers/file_provider.dart';
import '../utils/project_tree.dart';

/// After a project has been opened (which opens its default file), brings
/// back the file the user was last working in, if it still exists.
///
/// [remembered] must have been read BEFORE the project was opened, because
/// opening the default file changes what is remembered. The default tab is
/// closed again so only the remembered file is open.
Future<void> restoreLastFile(FileProvider files, String? remembered) async {
  if (remembered == null || !treeContainsFile(files.fileTree, remembered)) {
    return;
  }
  final others = files.openTabs.where((tab) => tab != remembered).toList();
  files.openFile(remembered);
  for (final path in others) {
    await files.closeTab(path, flush: true);
  }
}
