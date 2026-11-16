import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/project_file_node.dart';
import '../../models/project_model.dart';

/// Recursively scans a project's folder into a [ProjectFileNode]
/// tree, rooted at the project itself. Folders sort before files;
/// both sort alphabetically within their group.
Future<ProjectFileNode> scanProjectTree(ProjectModel project) async {
  final rootDir = Directory(project.rootPath);
  final children = await _scanDirectory(rootDir, project.rootPath);
  return ProjectFileNode(
    name: project.name,
    type: FileNodeType.folder,
    relativePath: '',
    children: children,
  );
}

Future<List<ProjectFileNode>> _scanDirectory(
  Directory dir,
  String projectRoot,
) async {
  final entries = await dir.list().toList();
  final nodes = <ProjectFileNode>[];

  for (final entry in entries) {
    final relativePath =
        p.relative(entry.path, from: projectRoot).replaceAll('\\', '/');
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
