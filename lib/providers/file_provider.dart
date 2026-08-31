import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/project_file_node.dart';
import '../models/project_model.dart';
import '../services/file_manager_service.dart';
import '../utils/constants.dart';

/// Project/file state for the whole app — now tracking multiple open
/// tabs (Phase 6) instead of Phase 5's single open file. Deliberately
/// still doesn't hold file *content*: EditorScreen owns one
/// CodeEditorController per open tab and reads/writes content itself,
/// this provider just tracks which paths are open, which is active,
/// and per-tab dirty/autosave state.
class FileProvider extends ChangeNotifier {
  final FileManagerService _service;

  FileProvider({FileManagerService? service}) : _service = service ?? FileManagerService();

  List<ProjectModel> _projects = [];
  ProjectModel? _currentProject;
  ProjectFileNode? _fileTree;
  bool _isLoadingProjects = false;

  final List<String> _openTabs = [];
  String? _activeTab;
  final Map<String, bool> _dirtyTabs = {};
  final Map<String, String> _pendingContent = {};
  final Map<String, Timer> _autoSaveTimers = {};

  List<ProjectModel> get projects => List.unmodifiable(_projects);
  ProjectModel? get currentProject => _currentProject;
  ProjectFileNode? get fileTree => _fileTree;
  bool get isLoadingProjects => _isLoadingProjects;

  List<String> get openTabs => List.unmodifiable(_openTabs);
  String? get activeTab => _activeTab;
  bool get hasActiveTab => _currentProject != null && _activeTab != null;
  String? get activeFileName => _activeTab?.split('/').last;
  bool isDirty(String relativePath) => _dirtyTabs[relativePath] ?? false;

  // ---- Projects ----

  Future<void> loadProjects() async {
    _isLoadingProjects = true;
    notifyListeners();
    _projects = await _service.listProjects();
    _isLoadingProjects = false;
    notifyListeners();
  }

  Future<ProjectModel> createProject(String name) async {
    final project = await _service.createProject(name);
    await loadProjects();
    return project;
  }

  Future<void> deleteProject(ProjectModel project) async {
    if (_currentProject?.id == project.id) {
      await _closeAllTabs(flush: false); // project is being deleted — nothing to save
      _currentProject = null;
      _fileTree = null;
    }
    await _service.deleteProject(project);
    await loadProjects();
  }

  /// Switches projects, closing (and flushing) whatever tabs were open
  /// from the previous one, then opens an initial file if it can find
  /// one (`main.dart` if present, else the first file in the tree).
  Future<void> openProject(ProjectModel project) async {
    await _closeAllTabs(flush: true);
    _currentProject = project;
    notifyListeners();

    await refreshFileTree();
    final defaultPath = _findDefaultFile(_fileTree);
    if (defaultPath != null) {
      openFile(defaultPath);
    }
  }

  String? _findDefaultFile(ProjectFileNode? node) {
    if (node == null) return null;
    for (final child in node.children) {
      if (child.isFile && child.name == 'main.dart') return child.relativePath;
    }
    for (final child in node.children) {
      if (child.isFile) return child.relativePath;
    }
    for (final child in node.children) {
      if (child.isFolder) {
        final found = _findDefaultFile(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  // ---- File tree ----

  Future<void> refreshFileTree() async {
    final project = _currentProject;
    if (project == null) return;
    _fileTree = await _service.listFileTree(project);
    notifyListeners();
  }

  Future<String> readFile(String relativePath) async {
    final project = _currentProject;
    if (project == null) return '';
    return _service.readFile(project, relativePath);
  }

  // ---- Tabs ----

  /// Opens [relativePath] as a tab (adding it if not already open) and
  /// makes it active. Doesn't touch content — EditorScreen reads it via
  /// [readFile] the first time it sees a new open tab.
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

  /// Closes a tab. Confirming with the user when it's dirty is the
  /// caller's job (Section 19) — by the time this runs, that decision
  /// has already been made. [flush] controls whether pending content
  /// gets written first (true = "save and close", false = "discard").
  Future<void> closeTab(String relativePath, {required bool flush}) async {
    _autoSaveTimers.remove(relativePath)?.cancel();
    if (flush) {
      final pending = _pendingContent.remove(relativePath);
      if (pending != null && (_dirtyTabs[relativePath] ?? false)) {
        await _writeNow(relativePath, pending);
      }
    } else {
      _pendingContent.remove(relativePath);
    }
    _dirtyTabs.remove(relativePath);

    final wasActive = _activeTab == relativePath;
    _openTabs.remove(relativePath);
    if (wasActive) {
      _activeTab = _openTabs.isNotEmpty ? _openTabs.last : null;
    }
    notifyListeners();
  }

  Future<void> _closeAllTabs({required bool flush}) async {
    for (final path in List<String>.from(_openTabs)) {
      await closeTab(path, flush: flush);
    }
  }

  // ---- Save / autosave (per tab) ----

  /// Called on every editor keystroke for whichever tab is being
  /// edited. Debounces so typing doesn't hit disk on every character
  /// (Section 22). Each open tab has its own independent timer, so
  /// switching the active tab never interferes with another tab's
  /// pending save.
  void scheduleAutoSave(String relativePath, String content) {
    if (_currentProject == null) return;
    _dirtyTabs[relativePath] = true;
    _pendingContent[relativePath] = content;
    notifyListeners();

    _autoSaveTimers[relativePath]?.cancel();
    _autoSaveTimers[relativePath] = Timer(AppConstants.autoSaveDebounce, () {
      unawaited(_writeNow(relativePath, content));
    });
  }

  Future<void> saveNow(String relativePath, String content) => _writeNow(relativePath, content);

  Future<void> flushPendingSave(String relativePath) async {
    _autoSaveTimers.remove(relativePath)?.cancel();
    final pending = _pendingContent[relativePath];
    if (pending != null && (_dirtyTabs[relativePath] ?? false)) {
      await _writeNow(relativePath, pending);
    }
  }

  /// Flushes every open tab — used when leaving the editor entirely
  /// (Section 22's "app lifecycle-এর সময় final save").
  Future<void> flushAllPendingSaves() async {
    for (final path in List<String>.from(_openTabs)) {
      await flushPendingSave(path);
    }
  }

  Future<void> _writeNow(String relativePath, String content) async {
    final project = _currentProject;
    if (project == null) return;
    await _service.writeFile(project, relativePath, content);
    _pendingContent.remove(relativePath);
    _dirtyTabs[relativePath] = false;
    notifyListeners();
  }

  // ---- File tree mutations ----

  Future<void> createFile(String parentRelativePath, String fileName) async {
    final project = _currentProject;
    if (project == null) return;
    final newPath = await _service.createFile(project, parentRelativePath, fileName);
    await refreshFileTree();
    openFile(newPath);
  }

  Future<void> createFolder(String parentRelativePath, String folderName) async {
    final project = _currentProject;
    if (project == null) return;
    await _service.createFolder(project, parentRelativePath, folderName);
    await refreshFileTree();
  }

  /// Renames a file or folder. If it (or, for a folder, anything open
  /// underneath it) is currently open in a tab, that tab's path — and
  /// its dirty/pending-save/timer state — moves with it, so an in-
  /// progress edit isn't lost just because the file got renamed.
  Future<void> renameEntry(String relativePath, String newName, {required bool isFolder}) async {
    final project = _currentProject;
    if (project == null) return;
    final newPath =
        await _service.renameEntry(project, relativePath, newName, isFolder: isFolder);

    if (!isFolder) {
      _renameTabReference(relativePath, newPath);
    } else {
      final oldPrefix = '$relativePath/';
      final newPrefix = '$newPath/';
      for (final oldTabPath in List<String>.from(_openTabs)) {
        if (oldTabPath.startsWith(oldPrefix)) {
          _renameTabReference(oldTabPath, newPrefix + oldTabPath.substring(oldPrefix.length));
        }
      }
    }
    await refreshFileTree();
  }

  void _renameTabReference(String oldPath, String newPath) {
    final index = _openTabs.indexOf(oldPath);
    if (index == -1) return;
    _openTabs[index] = newPath;
    if (_activeTab == oldPath) _activeTab = newPath;
    if (_dirtyTabs.containsKey(oldPath)) _dirtyTabs[newPath] = _dirtyTabs.remove(oldPath)!;
    if (_pendingContent.containsKey(oldPath)) {
      _pendingContent[newPath] = _pendingContent.remove(oldPath)!;
    }
    if (_autoSaveTimers.containsKey(oldPath)) {
      _autoSaveTimers[newPath] = _autoSaveTimers.remove(oldPath)!;
    }
  }

  Future<void> deleteEntry(String relativePath, {required bool isFolder}) async {
    final project = _currentProject;
    if (project == null) return;
    await _service.deleteEntry(project, relativePath, isFolder: isFolder);

    final affected = List<String>.from(_openTabs).where(
      (tabPath) => tabPath == relativePath || (isFolder && tabPath.startsWith('$relativePath/')),
    );
    for (final tabPath in affected) {
      await closeTab(tabPath, flush: false); // the file is gone — nothing left to save
    }
    await refreshFileTree();
  }

  @override
  void dispose() {
    for (final timer in _autoSaveTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
