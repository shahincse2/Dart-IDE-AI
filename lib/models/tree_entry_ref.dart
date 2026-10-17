/// A file or a folder of a project, by its path relative to the project.
class TreeEntryRef {
  const TreeEntryRef(this.path, {required this.isFolder});

  final String path;
  final bool isFolder;

  /// The last part of [path]: the name shown in the tree.
  String get name => path.split('/').last;

  @override
  bool operator ==(Object other) =>
      other is TreeEntryRef && other.path == path && other.isFolder == isFolder;

  @override
  int get hashCode => Object.hash(path, isFolder);
}
