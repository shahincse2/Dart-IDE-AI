import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/project_model.dart';
import 'entry_names.dart';
import 'file_defaults.dart';

/// Creating, importing, renaming, deleting, reading and writing the files and
/// folders inside one project.
class EntryOperations {
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
      importFile(project, parentRelativePath, fileName, kDefaultFileContent);

  /// Like [createFile] but with the given [content] (used by Import).
  Future<String> importFile(
    ProjectModel project,
    String parentRelativePath,
    String fileName,
    String content,
  ) async {
    var safeName = sanitizeName(fileName, fallback: 'untitled');
    if (!safeName.endsWith('.dart')) safeName = '$safeName.dart';

    final parentDir = Directory(p.join(project.rootPath, parentRelativePath));
    if (!await parentDir.exists()) await parentDir.create(recursive: true);

    final uniqueFile = await uniqueFileName(parentDir, safeName);
    final file = File(p.join(parentDir.path, uniqueFile));
    await file.writeAsString(content);

    return p.join(parentRelativePath, uniqueFile).replaceAll('\\', '/');
  }

  Future<String> createFolder(
    ProjectModel project,
    String parentRelativePath,
    String folderName,
  ) async {
    final safeName = sanitizeName(folderName, fallback: 'New Folder');
    final parentDir = Directory(p.join(project.rootPath, parentRelativePath));
    if (!await parentDir.exists()) await parentDir.create(recursive: true);

    final uniqueDir = await uniqueDirName(parentDir, safeName);
    final dir = Directory(p.join(parentDir.path, uniqueDir));
    await dir.create(recursive: true);

    return p.join(parentRelativePath, uniqueDir).replaceAll('\\', '/');
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
    var safeName = sanitizeName(newName, fallback: p.basename(relativePath));
    if (!isFolder && !safeName.endsWith('.dart')) safeName = '$safeName.dart';

    final newAbsolutePath = p.join(parent, safeName);
    if (isFolder) {
      await Directory(absolutePath).rename(newAbsolutePath);
    } else {
      await File(absolutePath).rename(newAbsolutePath);
    }
    return p
        .relative(newAbsolutePath, from: project.rootPath)
        .replaceAll('\\', '/');
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

  Future<void> writeFile(
    ProjectModel project,
    String relativePath,
    String content,
  ) {
    return File(p.join(project.rootPath, relativePath)).writeAsString(content);
  }
}
