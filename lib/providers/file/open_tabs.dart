import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../models/project_model.dart';
import '../../services/file_manager_service.dart';
import '../../utils/project_tree.dart';

/// Which files are open as tabs, and which tab is active, for [FileProvider].
/// Saving them is in [TabSaving].
///
/// Deliberately doesn't hold file *content*: EditorScreen owns one
/// CodeEditorController per open tab and reads/writes content itself; this
/// only tracks paths.
mixin OpenTabs on ChangeNotifier {
  final List<String> _openTabs = [];
  String? _activeTab;

  /// What the provider this is mixed into must have.
  ProjectModel? get currentProject;
  FileManagerService get fileService;

  List<String> get openTabs => List.unmodifiable(_openTabs);
  String? get activeTab => _activeTab;
  bool get hasActiveTab => currentProject != null && _activeTab != null;
  String? get activeFileName => _activeTab?.split('/').last;

  /// The folder of the active file (`` — the project root — when no file
  /// is open or the file sits directly in the root).
  String get activeFolder {
    final tab = _activeTab;
    return tab == null ? '' : parentOf(tab);
  }

  /// Opens [relativePath] as a tab (adding it if not already open) and
  /// makes it active. Doesn't touch content — EditorScreen reads it via
  /// `readFile` the first time it sees a new open tab.
  void openFile(String relativePath) {
    if (!_openTabs.contains(relativePath)) {
      _openTabs.add(relativePath);
    }
    _activeTab = relativePath;
    notifyListeners();
  }

  void setActiveTab(String relativePath) {
    if (!_openTabs.contains(relativePath) || _activeTab == relativePath) return;
    _activeTab = relativePath;
    notifyListeners();
  }

  /// Takes [path] out of the open tabs; the last tab becomes active if it was
  /// the active one. (Saving and telling the listeners is the caller's job.)
  @protected
  void removeOpenTab(String path) {
    final wasActive = _activeTab == path;
    _openTabs.remove(path);
    if (wasActive) {
      _activeTab = _openTabs.isNotEmpty ? _openTabs.last : null;
    }
  }

  /// The tab at [oldPath] is now at [newPath] (still the active one if it
  /// was). False when no tab was open at [oldPath].
  @protected
  bool renameOpenTab(String oldPath, String newPath) {
    final index = _openTabs.indexOf(oldPath);
    if (index == -1) return false;
    _openTabs[index] = newPath;
    if (_activeTab == oldPath) _activeTab = newPath;
    return true;
  }

  /// The open tabs on [relativePath] (or, for a folder, below it).
  @protected
  List<String> tabsOn(String relativePath, {required bool isFolder}) => [
        for (final tab in _openTabs)
          if (tab == relativePath ||
              (isFolder && tab.startsWith('$relativePath/')))
            tab,
      ];

  // ---- Export ----

  /// Returns the absolute path of the currently active file,
  /// or null if no file is open. Used by the export action to
  /// locate the file on disk without re-reading its content.
  String? getActiveFilePath() {
    final project = currentProject;
    final tab = _activeTab;
    if (project == null || tab == null) return null;
    return p.join(project.rootPath, tab);
  }
}
