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
