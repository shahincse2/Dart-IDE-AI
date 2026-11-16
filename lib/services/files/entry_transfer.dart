import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/project_model.dart';
import 'entry_copy.dart';
import 'entry_names.dart';

/// Moving and copying files and folders, inside a project or into another.
class EntryTransfer {
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
    if (isFolder &&
        sameProject &&
        isInside(destinationRelativePath, relativePath)) {
      throw ArgumentError('A folder cannot be moved into itself.');
    }

    final source = p.join(project.rootPath, relativePath);
    final destination =
        Directory(p.join(target.rootPath, destinationRelativePath));
    if (sameProject && p.equals(p.dirname(source), destination.path)) {
      return relativePath;
    }
    if (!await destination.exists()) await destination.create(recursive: true);

    final unique = await uniqueName(destination, p.basename(relativePath),
        isFolder: isFolder);
    final targetPath = p.join(destination.path, unique);

    try {
      if (isFolder) {
        await Directory(source).rename(targetPath);
      } else {
        await File(source).rename(targetPath);
      }
    } on FileSystemException {
      // Renaming can fail when source and target are on different drives:
      // copy, then remove the original.
      await copyTo(source, targetPath, isFolder: isFolder);
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
    if (isFolder &&
        sameProject &&
        isInside(destinationRelativePath, relativePath)) {
      throw ArgumentError('A folder cannot be copied into itself.');
    }

    final source = p.join(project.rootPath, relativePath);
    final destination =
        Directory(p.join(target.rootPath, destinationRelativePath));
    if (!await destination.exists()) await destination.create(recursive: true);

    final unique = await uniqueName(destination, p.basename(relativePath),
        isFolder: isFolder);
    final targetPath = p.join(destination.path, unique);
    await copyTo(source, targetPath, isFolder: isFolder);
    return p.relative(targetPath, from: target.rootPath).replaceAll('\\', '/');
  }
}
