import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/project_file_node.dart';
import '../models/project_model.dart';

/// Every real filesystem operation DartLab needs: listing/creating/
/// renaming/deleting projects, files, and folders, plus read/write for
/// the editor's Save. Providers call these; nothing here talks to
/// Flutter widgets, and nothing above this layer touches `dart:io`
/// directly (Section 47 — no business logic in widgets, and here,
/// none in providers either).
class FileManagerService {
  static const String _defaultFileContent = "void main() {\n  \n}\n";

  Future<Directory> _projectsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'projects'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ---- Projects ----

  Future<List<ProjectModel>> listProjects() async {
    final root = await _projectsRoot();
    final entries = await root.list().toList();
    final projects = entries.whereType<Directory>().map((dir) {
      final name = p.basename(dir.path);
      return ProjectModel(id: name, name: name, rootPath: dir.path);
    }).toList();
    projects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return projects;
  }

  /// Creates a new project folder with a starter `main.dart`. If
  /// [name] collides with an existing project, appends " (2)", " (3)",
  /// etc. rather than silently overwriting.
  Future<ProjectModel> createProject(String name) async {
    final root = await _projectsRoot();
    final safeName = _sanitizeName(name, fallback: 'Untitled Project');
    final uniqueName = await _uniqueDirName(root, safeName);
    final projectDir = Directory(p.join(root.path, uniqueName));
    await projectDir.create(recursive: true);

    final mainFile = File(p.join(projectDir.path, 'main.dart'));
    await mainFile.writeAsString(_defaultFileContent);

    return ProjectModel(id: uniqueName, name: uniqueName, rootPath: projectDir.path);
  }

  Future<void> deleteProject(ProjectModel project) async {
    final dir = Directory(project.rootPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Renames the project's folder. Returns the updated model — the
  /// caller (FileProvider) is responsible for updating any open-file
  /// references, since their absolute paths change too.
  Future<ProjectModel> renameProject(ProjectModel project, String newName) async {
    final root = await _projectsRoot();
    final safeName = _sanitizeName(newName, fallback: project.name);
    if (safeName == project.name) return project;
    final uniqueName = await _uniqueDirName(root, safeName);
    final newPath = p.join(root.path, uniqueName);
    await Directory(project.rootPath).rename(newPath);
    return ProjectModel(id: uniqueName, name: uniqueName, rootPath: newPath);
  }

  // ---- File tree ----

  /// Recursively scans a project's folder into a [ProjectFileNode]
  /// tree, rooted at the project itself. Folders sort before files;
  /// both sort alphabetically within their group.
  Future<ProjectFileNode> listFileTree(ProjectModel project) async {
    final rootDir = Directory(project.rootPath);
    final children = await _scanDirectory(rootDir, project.rootPath);
    return ProjectFileNode(
      name: project.name,
      type: FileNodeType.folder,
      relativePath: '',
      children: children,
    );
  }

  Future<List<ProjectFileNode>> _scanDirectory(Directory dir, String projectRoot) async {
    final entries = await dir.list().toList();
    final nodes = <ProjectFileNode>[];

    for (final entry in entries) {
      final relativePath = p.relative(entry.path, from: projectRoot).replaceAll('\\', '/');
      if (entry is Directory) {
        final children = await _scanDirectory(entry, projectRoot);
        nodes.add(ProjectFileNode(
          name: p.basename(entry.path),
          type: FileNodeType.folder,
          relativePath: relativePath,
          children: children,
        ));
      } else if (entry is File) {
        nodes.add(ProjectFileNode(
          name: p.basename(entry.path),
          type: FileNodeType.file,
          relativePath: relativePath,
        ));
      }
    }

    nodes.sort((a, b) {
      if (a.type != b.type) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return nodes;
  }

  // ---- Files & folders within a project ----

  /// Creates a new file inside [parentRelativePath] (empty string for
  /// the project root). If [fileName] doesn't end in `.dart`, that
  /// extension is added — DartLab only edits Dart source. Returns the
  /// final relative path, which may differ from the requested name if
  /// a file with that name already existed (a numbered suffix is
  /// added rather than overwriting).
  Future<String> createFile(
    ProjectModel project,
    String parentRelativePath,
    String fileName,
  ) =>
      importFile(project, parentRelativePath, fileName, _defaultFileContent);

  /// Like [createFile] but with the given [content] (used by Import).
  Future<String> importFile(
    ProjectModel project,
    String parentRelativePath,
    String fileName,
    String content,
  ) async {
    var safeName = _sanitizeName(fileName, fallback: 'untitled');
    if (!safeName.endsWith('.dart')) safeName = '$safeName.dart';

    final parentDir = Directory(p.join(project.rootPath, parentRelativePath));
    if (!await parentDir.exists()) await parentDir.create(recursive: true);

    final uniqueName = await _uniqueFileName(parentDir, safeName);
    final file = File(p.join(parentDir.path, uniqueName));
    await file.writeAsString(content);

    return p.join(parentRelativePath, uniqueName).replaceAll('\\', '/');
  }

  Future<String> createFolder(
    ProjectModel project,
    String parentRelativePath,
    String folderName,
  ) async {
    final safeName = _sanitizeName(folderName, fallback: 'New Folder');
    final parentDir = Directory(p.join(project.rootPath, parentRelativePath));
    if (!await parentDir.exists()) await parentDir.create(recursive: true);

    final uniqueName = await _uniqueDirName(parentDir, safeName);
    final dir = Directory(p.join(parentDir.path, uniqueName));
    await dir.create(recursive: true);

    return p.join(parentRelativePath, uniqueName).replaceAll('\\', '/');
  }

  /// Renames a file or folder in place (same parent directory).
  /// Returns the new relative path.
  Future<String> renameEntry(
    ProjectModel project,
    String relativePath,
    String newName, {
    required bool isFolder,
  }) async {
    final absolutePath = p.join(project.rootPath, relativePath);
    final parent = p.dirname(absolutePath);
    var safeName = _sanitizeName(newName, fallback: p.basename(relativePath));
    if (!isFolder && !safeName.endsWith('.dart')) safeName = '$safeName.dart';

    final newAbsolutePath = p.join(parent, safeName);
    if (isFolder) {
      await Directory(absolutePath).rename(newAbsolutePath);
    } else {
      await File(absolutePath).rename(newAbsolutePath);
    }
    return p.relative(newAbsolutePath, from: project.rootPath).replaceAll('\\', '/');
  }

  /// Moves a file or folder into [destinationRelativePath] (empty string
  /// for the project root) of [toProject] (this project when null), keeping
  /// its name; a numbered suffix is added if that name is already taken
  /// there. Returns the new relative path inside the target project.
  ///
  /// Moving something into the folder it is already in changes nothing, and
  /// a folder cannot be moved into itself or below itself ([ArgumentError]).
  Future<String> moveEntry(
    ProjectModel project,
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) async {
    final target = toProject ?? project;
    final sameProject = target.rootPath == project.rootPath;
    if (isFolder && sameProject && _isInside(destinationRelativePath, relativePath)) {
      throw ArgumentError('A folder cannot be moved into itself.');
    }

    final source = p.join(project.rootPath, relativePath);
    final destination = Directory(p.join(target.rootPath, destinationRelativePath));
    if (sameProject && p.equals(p.dirname(source), destination.path)) {
      return relativePath;
    }
    if (!await destination.exists()) await destination.create(recursive: true);

    final uniqueName = await _uniqueName(destination, p.basename(relativePath), isFolder: isFolder);
    final targetPath = p.join(destination.path, uniqueName);

    try {
      if (isFolder) {
        await Directory(source).rename(targetPath);
      } else {
        await File(source).rename(targetPath);
      }
    } on FileSystemException {
      // Renaming can fail when source and target are on different drives:
      // copy, then remove the original.
      await _copyTo(source, targetPath, isFolder: isFolder);
      if (isFolder) {
        await Directory(source).delete(recursive: true);
      } else {
        await File(source).delete();
      }
    }
    return p.relative(targetPath, from: target.rootPath).replaceAll('\\', '/');
  }

  /// Copies a file or folder (with everything inside it) into
  /// [destinationRelativePath] of [toProject] (this project when null). The
  /// original stays. A numbered suffix is added if the name is already taken
  /// there, so copying into the folder it is already in makes a duplicate.
  /// Returns the new relative path inside the target project.
  ///
  /// A folder cannot be copied into itself or below itself ([ArgumentError]).
  Future<String> copyEntry(
    ProjectModel project,
    String relativePath,
    String destinationRelativePath, {
    required bool isFolder,
    ProjectModel? toProject,
  }) async {
    final target = toProject ?? project;
    final sameProject = target.rootPath == project.rootPath;
    if (isFolder && sameProject && _isInside(destinationRelativePath, relativePath)) {
      throw ArgumentError('A folder cannot be copied into itself.');
    }

    final source = p.join(project.rootPath, relativePath);
    final destination = Directory(p.join(target.rootPath, destinationRelativePath));
    if (!await destination.exists()) await destination.create(recursive: true);

    final uniqueName = await _uniqueName(destination, p.basename(relativePath), isFolder: isFolder);
    final targetPath = p.join(destination.path, uniqueName);
    await _copyTo(source, targetPath, isFolder: isFolder);
    return p.relative(targetPath, from: target.rootPath).replaceAll('\\', '/');
  }

  Future<void> deleteEntry(
    ProjectModel project,
    String relativePath, {
    required bool isFolder,
  }) async {
    final absolutePath = p.join(project.rootPath, relativePath);
    if (isFolder) {
      final dir = Directory(absolutePath);
      if (await dir.exists()) await dir.delete(recursive: true);
    } else {
      final file = File(absolutePath);
      if (await file.exists()) await file.delete();
    }
  }

  // ---- Reading & writing file content (used by Save/autosave) ----

  Future<String> readFile(ProjectModel project, String relativePath) {
    return File(p.join(project.rootPath, relativePath)).readAsString();
  }

  Future<void> writeFile(ProjectModel project, String relativePath, String content) {
    return File(p.join(project.rootPath, relativePath)).writeAsString(content);
  }

  // ---- Helpers ----

  /// Strips path separators and trims whitespace so a user-typed name
  /// can't escape its intended directory or produce an empty/invalid
  /// filesystem entry.
  String _sanitizeName(String input, {required String fallback}) {
    final cleaned = input.replaceAll(RegExp(r'[\\/]'), '').trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  Future<String> _uniqueDirName(Directory parent, String name) async {
    var candidate = name;
    var attempt = 1;
    while (await Directory(p.join(parent.path, candidate)).exists()) {
      attempt++;
      candidate = '$name ($attempt)';
    }
    return candidate;
  }

  Future<String> _uniqueFileName(Directory parent, String name) async {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    var candidate = name;
    var attempt = 1;
    while (await File(p.join(parent.path, candidate)).exists()) {
      attempt++;
      candidate = '$base ($attempt)$ext';
    }
    return candidate;
  }

  /// True if [path] is [folder] itself or lies below it.
  bool _isInside(String path, String folder) =>
      path == folder || path.startsWith('$folder/');

  Future<String> _uniqueName(Directory parent, String name, {required bool isFolder}) =>
      isFolder ? _uniqueDirName(parent, name) : _uniqueFileName(parent, name);

  Future<void> _copyTo(String source, String targetPath, {required bool isFolder}) async {
    if (isFolder) {
      await _copyDirectory(Directory(source), Directory(targetPath));
    } else {
      await File(source).copy(targetPath);
    }
  }

  Future<void> _copyDirectory(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final entity in from.list()) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(p.join(to.path, name)));
      } else if (entity is File) {
        await entity.copy(p.join(to.path, name));
      }
    }
  }
}
