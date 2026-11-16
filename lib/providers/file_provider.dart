import 'package:flutter/foundation.dart';

import '../models/project_file_node.dart';
import '../models/project_model.dart';
import '../services/file_manager_service.dart';
import 'file/open_tabs.dart';
import 'file/tab_saving.dart';
import 'file/tree_mutations.dart';
import 'file/tree_transfers.dart';

/// Project/file state for the whole app: the projects, the open project and
/// its file tree. The open tabs are in [OpenTabs] and their saving in
/// [TabSaving]; creating, renaming and deleting files are in [TreeMutations],
/// moving and copying them in [TreeTransfers].
///
/// Deliberately doesn't hold file *content*: EditorScreen owns one
/// CodeEditorController per open tab and reads/writes content itself, this
/// provider just tracks which paths are open, which is active, and per-tab
/// dirty/autosave state.
class FileProvider extends ChangeNotifier
    with OpenTabs, TabSaving, TreeMutations, TreeTransfers {
  final FileManagerService _service;

  FileProvider({FileManagerService? service})
      : _service = service ?? FileManagerService();

  List<ProjectModel> _projects = [];
  ProjectModel? _currentProject;
  ProjectFileNode? _fileTree;
  bool _isLoadingProjects = false;

  @override
  FileManagerService get fileService => _service;

  List<ProjectModel> get projects => List.unmodifiable(_projects);
  @override
  ProjectModel? get currentProject => _currentProject;
  ProjectFileNode? get fileTree => _fileTree;
  bool get isLoadingProjects => _isLoadingProjects;

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
      await closeAllTabs(
        flush: false,
      ); // project is being deleted — nothing to save
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
    await closeAllTabs(flush: true);
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

  @override
  Future<void> refreshFileTree() async {
    final project = _currentProject;
    if (project == null) return;
    _fileTree = await _service.listFileTree(project);
    notifyListeners();
  }

  /// A fresh scan of [project]'s files (any project, not only the open one).
  Future<ProjectFileNode> treeOf(ProjectModel project) =>
      _service.listFileTree(project);

  Future<String> readFile(String relativePath) async {
    final project = _currentProject;
    if (project == null) return '';
    return _service.readFile(project, relativePath);
  }

  @override
  void dispose() {
    cancelAutoSaveTimers();
    super.dispose();
  }
}
