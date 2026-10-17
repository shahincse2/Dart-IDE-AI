import '../models/project_file_node.dart';

/// True if [relativePath] is a file somewhere under [node].
bool treeContainsFile(ProjectFileNode? node, String relativePath) {
  if (node == null) return false;
  for (final child in node.children) {
    final found = child.isFile
        ? child.relativePath == relativePath
        : treeContainsFile(child, relativePath);
    if (found) return true;
  }
  return false;
}

/// The folder a relative path lives in: `lib/src/b.dart` -> `lib/src`,
/// `main.dart` -> `` (the project root).
String parentOf(String relativePath) {
  final slash = relativePath.lastIndexOf('/');
  return slash == -1 ? '' : relativePath.substring(0, slash);
}
