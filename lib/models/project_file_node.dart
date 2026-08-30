enum FileNodeType { file, folder }

/// One entry in a project's file tree. Folders carry their children;
/// files don't. [relativePath] (forward-slash separated, relative to
/// the project root) doubles as this node's stable id — no separate
/// UUID needed since it's already unique within a project.
class ProjectFileNode {
  final String name;
  final FileNodeType type;
  final String relativePath;
  final List<ProjectFileNode> children;

  const ProjectFileNode({
    required this.name,
    required this.type,
    required this.relativePath,
    this.children = const [],
  });

  bool get isFile => type == FileNodeType.file;
  bool get isFolder => type == FileNodeType.folder;

  ProjectFileNode copyWith({List<ProjectFileNode>? children}) {
    return ProjectFileNode(
      name: name,
      type: type,
      relativePath: relativePath,
      children: children ?? this.children,
    );
  }
}
