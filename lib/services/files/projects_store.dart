import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/project_model.dart';
import 'entry_names.dart';
import 'file_defaults.dart';

/// The project folders: listing, creating, deleting, renaming.
class ProjectsStore {
  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'projects'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<ProjectModel>> list() async {
    final root = await _root();
    final entries = await root.list().toList();
    final projects = entries.whereType<Directory>().map((dir) {
      final name = p.basename(dir.path);
      return ProjectModel(id: name, name: name, rootPath: dir.path);
    }).toList();
    projects
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return projects;
  }

  /// Creates a new project folder with a starter `main.dart`. If
  /// [name] collides with an existing project, appends " (2)", " (3)",
  /// etc. rather than silently overwriting.
  Future<ProjectModel> create(String name) async {
    final root = await _root();
    final safeName = sanitizeName(name, fallback: 'Untitled Project');
    final uniqueDir = await uniqueDirName(root, safeName);
    final projectDir = Directory(p.join(root.path, uniqueDir));
    await projectDir.create(recursive: true);

    final mainFile = File(p.join(projectDir.path, 'main.dart'));
    await mainFile.writeAsString(kDefaultFileContent);

    return ProjectModel(
        id: uniqueDir, name: uniqueDir, rootPath: projectDir.path);
  }

  Future<void> delete(ProjectModel project) async {
    final dir = Directory(project.rootPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Renames the project's folder. Returns the updated model — the
  /// caller (FileProvider) is responsible for updating any open-file
  /// references, since their absolute paths change too.
  Future<ProjectModel> rename(ProjectModel project, String newName) async {
    final root = await _root();
    final safeName = sanitizeName(newName, fallback: project.name);
    if (safeName == project.name) return project;
    final uniqueDir = await uniqueDirName(root, safeName);
    final newPath = p.join(root.path, uniqueDir);
    await Directory(project.rootPath).rename(newPath);
    return ProjectModel(id: uniqueDir, name: uniqueDir, rootPath: newPath);
  }
}
