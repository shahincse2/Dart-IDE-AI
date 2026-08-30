import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/project_file_node.dart';
import '../models/project_model.dart';
import '../services/file_manager_service.dart';
import '../utils/constants.dart';

/// Project/file state for the whole app. EditorScreen and the file
/// tree UI (Part 3) both read from this rather than touching
/// [FileManagerService] directly.
class FileProvider extends ChangeNotifier {
  final FileManagerService _service;

  FileProvider({FileManagerService? service}) : _service = service ?? FileManagerService();

  List<ProjectModel> _projects = [];
  ProjectModel? _currentProject;
  ProjectFileNode? _fileTree;
  String? _openFileRelativePath;
  bool _isLoadingProjects = false;
  bool _isDirty = false;

  Timer? _autoSaveTimer;
  String? _pendingContent;

  List<ProjectModel> get projects => List.unmodifiable(_projects);
  ProjectModel? get currentProject => _currentProject;
  ProjectFileNode? get fileTree => _fileTree;
  String? get openFileRelativePath => _openFileRelativePath;
  bool get isDirty => _isDirty;
  bool get isLoadingProjects => _isLoadingProjects;
  bool get hasOpenFile => _currentProject != null && _openFileRelativePath != null;

  String? get openFileName => _openFileRelativePath?.split('/').last;

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
      _autoSaveTimer?.cancel();
      _pendingContent = null;
      _currentProject = null;
      _fileTree = null;
      _openFileRelativePath = null;
      _isDirty = false;
    }
    await _service.deleteProject(project);
    await loadProjects();
  }

  /// Opens a project and, if it can find one, an initial file
  /// (`main.dart` if present, otherwise the first file in the tree).
  Future<void> openProject(ProjectModel project) async {
    await flushPendingSave();
    _currentProject = project;
    _openFileRelativePath = null;
    _isDirty = false;
    notifyListeners();

    await refreshFileTree();
    final defaultPath = _findDefaultFile(_fileTree);
    if (defaultPath != null) {
      _openFileRelativePath = defaultPath;
      notifyListeners();
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

  Future<String> readOpenFile() async {
    final project = _currentProject;
    final path = _openFileRelativePath;
    if (project == null || path == null) return '';
    return _service.readFile(project, path);
  }

  /// Switches the open file, flushing any pending autosave for the
  /// previous one first so an edit can't be lost between the debounce
  /// window and the switch.
  Future<void> openFile(String relativePath) async {
    await flushPendingSave();
    _openFileRelativePath = relativePath;
    _isDirty = false;
    notifyListeners();
  }

  // ---- Save / autosave ----

  /// Called on every editor keystroke. Debounces so typing doesn't
  /// hit disk on every character (Section 22: edits → debounce → save).
  void scheduleAutoSave(String content) {
    if (!hasOpenFile) return;
    _isDirty = true;
    _pendingContent = content;
    notifyListeners();

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(AppConstants.autoSaveDebounce, () {
      unawaited(_saveNow(content));
    });
  }

  /// Saves immediately, bypassing the debounce (the app bar's Save
  /// button, and app-lifecycle-pause per Section 22's "final save").
  Future<void> saveNow(String content) => _saveNow(content);

  Future<void> flushPendingSave() async {
    _autoSaveTimer?.cancel();
    final pending = _pendingContent;
    if (pending != null && _isDirty) {
      await _saveNow(pending);
    }
  }

  Future<void> _saveNow(String content) async {
    final project = _currentProject;
    final path = _openFileRelativePath;
    if (project == null || path == null) return;
    await _service.writeFile(project, path, content);
    _pendingContent = null;
    _isDirty = false;
    notifyListeners();
  }

  // ---- File tree mutations ----

  Future<void> createFile(String parentRelativePath, String fileName) async {
    final project = _currentProject;
    if (project == null) return;
    final newPath = await _service.createFile(project, parentRelativePath, fileName);
    await refreshFileTree();
    await openFile(newPath);
  }

  Future<void> createFolder(String parentRelativePath, String folderName) async {
    final project = _currentProject;
    if (project == null) return;
    await _service.createFolder(project, parentRelativePath, folderName);
    await refreshFileTree();
  }

  Future<void> renameEntry(String relativePath, String newName, {required bool isFolder}) async {
    final project = _currentProject;
    if (project == null) return;
    final newPath =
        await _service.renameEntry(project, relativePath, newName, isFolder: isFolder);
    if (_openFileRelativePath == relativePath) {
      _openFileRelativePath = newPath;
    }
    await refreshFileTree();
  }

  Future<void> deleteEntry(String relativePath, {required bool isFolder}) async {
    final project = _currentProject;
    if (project == null) return;
    await _service.deleteEntry(project, relativePath, isFolder: isFolder);

    final openPath = _openFileRelativePath;
    final closedOpenFile = openPath != null &&
        (openPath == relativePath || (isFolder && openPath.startsWith('$relativePath/')));
    if (closedOpenFile) {
      _autoSaveTimer?.cancel();
      _pendingContent = null;
      _openFileRelativePath = null;
      _isDirty = false;
    }
    await refreshFileTree();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
