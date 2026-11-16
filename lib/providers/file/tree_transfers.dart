import 'package:flutter/foundation.dart';

import '../../models/project_model.dart';
import '../../models/tree_entry_ref.dart';
import 'open_tabs.dart';
import 'tab_saving.dart';

/// Moving and copying files and folders for [FileProvider], inside the open
/// project or into another. Open tabs follow a moved file, or close when it
/// leaves this project.
mixin TreeTransfers on ChangeNotifier, OpenTabs, TabSaving {
  /// Reads the project's files again and tells the listeners.
  Future<void> refreshFileTree();

  /// Moves a file or folder into [destinationRelativePath] (`` for the
  /// project root) of [toProject] (this project when null). Tabs open on it
  /// (or below it) follow it, or close when it leaves this project.
  Future<void> moveEntry(
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) async {
    await _moveOne(relativePath, destinationRelativePath,
        isFolder: isFolder, toProject: toProject);
    await refreshFileTree();
  }

  /// Copies a file or folder like [moveEntry] moves it; the original and its
  /// tabs stay as they are.
  Future<void> copyEntry(
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) async {
    await _copyOne(relativePath, destinationRelativePath,
        isFolder: isFolder, toProject: toProject);
    await refreshFileTree();
  }

  /// Copies or moves several entries into one folder. One that fails does
  /// not stop the others; returns how many failed.
  Future<int> transferEntries(
    List<TreeEntryRef> entries,
    String destinationRelativePath, {
    required bool copy,
    ProjectModel? toProject,
  }) async {
    var failed = 0;
    for (final entry in entries) {
      try {
        if (copy) {
          await _copyOne(entry.path, destinationRelativePath,
              isFolder: entry.isFolder, toProject: toProject);
        } else {
          await _moveOne(entry.path, destinationRelativePath,
              isFolder: entry.isFolder, toProject: toProject);
        }
      } on Exception {
        failed++;
      } on ArgumentError {
        failed++;
      }
    }
    await refreshFileTree();
    return failed;
  }

  Future<void> _moveOne(
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) async {
    final project = currentProject;
    if (project == null) return;

    // Write pending edits first, so no save is left waiting for the old path
    // (it would write the file back where it used to be).
    await flushTabsOn(relativePath, isFolder: isFolder);

    final leaves = _isOtherProject(toProject);
    final newPath = await fileService.moveEntry(
      project,
      relativePath,
      destinationRelativePath,
      isFolder: isFolder,
      toProject: leaves ? toProject : null,
    );
    if (leaves) {
      for (final tab in tabsOn(relativePath, isFolder: isFolder)) {
        await closeTab(tab, flush: false); // already written above
      }
    } else {
      followToNewPath(relativePath, newPath, isFolder: isFolder);
    }
  }

  Future<void> _copyOne(
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) async {
    final project = currentProject;
    if (project == null) return;
    // The copy should contain what the user sees, saved or not.
    await flushTabsOn(relativePath, isFolder: isFolder);
    await fileService.copyEntry(
      project,
      relativePath,
      destinationRelativePath,
      isFolder: isFolder,
      toProject: _isOtherProject(toProject) ? toProject : null,
    );
  }

  bool _isOtherProject(ProjectModel? target) =>
      target != null && target.id != currentProject?.id;
}
