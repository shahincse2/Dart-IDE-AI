import 'package:flutter/foundation.dart';

import 'open_tabs.dart';
import 'tab_saving.dart';

/// Creating, importing, renaming and deleting files and folders for
/// [FileProvider]. Open tabs follow their file when it is renamed, and close
/// when it goes away. Moving and copying are in [TreeTransfers].
mixin TreeMutations on ChangeNotifier, OpenTabs, TabSaving {
  /// Reads the project's files again and tells the listeners.
  Future<void> refreshFileTree();

  Future<void> createFile(String parentRelativePath, String fileName) async {
    final project = currentProject;
    if (project == null) return;
    final newPath = await fileService.createFile(
      project,
      parentRelativePath,
      fileName,
    );
    await refreshFileTree();
    openFile(newPath);
  }

  /// Creates a file with [content] (an imported one) in
  /// [parentRelativePath] — the project root by default — and opens it.
  Future<void> importFile(
    String fileName,
    String content, {
    String parentRelativePath = '',
  }) async {
    final project = currentProject;
    if (project == null) return;
    final newPath = await fileService.importFile(
      project,
      parentRelativePath,
      fileName,
      content,
    );
    await refreshFileTree();
    openFile(newPath);
  }

  Future<void> createFolder(
    String parentRelativePath,
    String folderName,
  ) async {
    final project = currentProject;
    if (project == null) return;
    await fileService.createFolder(project, parentRelativePath, folderName);
    await refreshFileTree();
  }

  /// Renames a file or folder. If it (or, for a folder, anything open
  /// underneath it) is currently open in a tab, that tab's path — and
  /// its dirty/pending-save/timer state — moves with it, so an in-
  /// progress edit isn't lost just because the file got renamed.
  Future<void> renameEntry(
    String relativePath,
    String newName, {
    required bool isFolder,
  }) async {
    final project = currentProject;
    if (project == null) return;
    // Write pending edits first. The autosave timer knows only the OLD path:
    // left waiting, it would write the edit there and bring the old file back.
    await flushTabsOn(relativePath, isFolder: isFolder);
    final newPath = await fileService.renameEntry(
      project,
      relativePath,
      newName,
      isFolder: isFolder,
    );
    followToNewPath(relativePath, newPath, isFolder: isFolder);
    await refreshFileTree();
  }

  Future<void> deleteEntry(
    String relativePath, {
    required bool isFolder,
  }) async {
    final project = currentProject;
    if (project == null) return;
    await fileService.deleteEntry(project, relativePath, isFolder: isFolder);

    for (final tabPath in tabsOn(relativePath, isFolder: isFolder)) {
      await closeTab(
        tabPath,
        flush: false,
      ); // the file is gone — nothing left to save
    }
    await refreshFileTree();
  }
}
