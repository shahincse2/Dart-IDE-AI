import '../models/project_file_node.dart';
import '../models/project_model.dart';
import 'files/entry_operations.dart';
import 'files/entry_transfer.dart';
import 'files/project_tree_scanner.dart';
import 'files/projects_store.dart';

/// Every real filesystem operation DartLab needs: listing/creating/
/// renaming/deleting projects, files, and folders, plus read/write for
/// the editor's Save. Providers call these; nothing here talks to
/// Flutter widgets, and nothing above this layer touches `dart:io`
/// directly (Section 47 — no business logic in widgets, and here,
/// none in providers either).
///
/// The work itself is in `files/`: the project folders ([ProjectsStore]),
/// the tree scan, the file and folder operations ([EntryOperations]) and
/// moving and copying ([EntryTransfer]). This class is the one door to them.
class FileManagerService {
  final ProjectsStore _projects = ProjectsStore();
  final EntryOperations _entries = EntryOperations();
  final EntryTransfer _transfer = EntryTransfer();

  // ---- Projects ----

  Future<List<ProjectModel>> listProjects() => _projects.list();

  /// Creates a new project folder with a starter `main.dart` (a numbered
  /// suffix when the name is taken).
  Future<ProjectModel> createProject(String name) => _projects.create(name);

  Future<void> deleteProject(ProjectModel project) => _projects.delete(project);

  /// Renames the project's folder. Returns the updated model — the
  /// caller (FileProvider) is responsible for updating any open-file
  /// references, since their absolute paths change too.
  Future<ProjectModel> renameProject(ProjectModel project, String newName) =>
      _projects.rename(project, newName);

  // ---- File tree ----

  /// The project's files as a tree; folders first, then files, each sorted.
  Future<ProjectFileNode> listFileTree(ProjectModel project) =>
      scanProjectTree(project);

  // ---- Files & folders within a project ----

  /// A new file (`.dart` is added to the name); returns its relative path.
  Future<String> createFile(
    ProjectModel project,
    String parentRelativePath,
    String fileName,
  ) =>
      _entries.createFile(project, parentRelativePath, fileName);

  /// Like [createFile] but with the given [content] (used by Import).
  Future<String> importFile(
    ProjectModel project,
    String parentRelativePath,
    String fileName,
    String content,
  ) =>
      _entries.importFile(project, parentRelativePath, fileName, content);

  Future<String> createFolder(
    ProjectModel project,
    String parentRelativePath,
    String folderName,
  ) =>
      _entries.createFolder(project, parentRelativePath, folderName);

  /// Renames a file or folder in place; returns the new relative path.
  Future<String> renameEntry(
    ProjectModel project,
    String relativePath,
    String newName, {
    required bool isFolder,
  }) =>
      _entries.renameEntry(project, relativePath, newName, isFolder: isFolder);

  /// Moves a file or folder into [destinationRelativePath] of [toProject]
  /// (this project when null); returns the new relative path there. A folder
  /// cannot be moved into itself ([ArgumentError]).
  Future<String> moveEntry(
    ProjectModel project,
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) =>
      _transfer.moveEntry(
        project,
        relativePath,
        destinationRelativePath,
        isFolder: isFolder,
        toProject: toProject,
      );

  /// Copies a file or folder like [moveEntry] moves it; the original stays.
  Future<String> copyEntry(
    ProjectModel project,
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) =>
      _transfer.copyEntry(
        project,
        relativePath,
        destinationRelativePath,
        isFolder: isFolder,
        toProject: toProject,
      );

  Future<void> deleteEntry(
    ProjectModel project,
    String relativePath, {
    required bool isFolder,
  }) =>
      _entries.deleteEntry(project, relativePath, isFolder: isFolder);

  // ---- Reading & writing file content (used by Save/autosave) ----

  Future<String> readFile(ProjectModel project, String relativePath) =>
      _entries.readFile(project, relativePath);

  Future<void> writeFile(
    ProjectModel project,
    String relativePath,
    String content,
  ) =>
      _entries.writeFile(project, relativePath, content);
}
