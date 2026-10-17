import '../models/project_file_node.dart';
import '../models/tree_entry_ref.dart';
import 'project_tree.dart';

/// A folder files can be copied or moved into. [relativePath] is `` for the
/// project root; [depth] is how deep it sits (for indenting a list).
class TransferDestination {
  const TransferDestination({
    required this.relativePath,
    required this.label,
    required this.depth,
  });

  final String relativePath;
  final String label;
  final int depth;
}

/// Drops entries that sit inside another selected folder (they travel with
/// it) and repeated entries, so nothing is moved or copied twice.
List<TreeEntryRef> withoutNested(List<TreeEntryRef> entries) {
  final folders = [
    for (final entry in entries)
      if (entry.isFolder) entry.path,
  ];
  final seen = <String>{};
  return [
    for (final entry in entries)
      if (seen.add(entry.path) &&
          !folders.any((folder) => entry.path.startsWith('$folder/')))
        entry,
  ];
}

/// The folders of [root] that [entries] may be copied or moved into, in tree
/// order. [sameProject] says whether [root] is the project they come from.
///
/// Within the same project a folder cannot go into itself or below itself,
/// and a move into the folder everything is already in changes nothing, so
/// that folder is left out (a copy there is a duplicate, which is allowed).
/// Another project accepts every folder.
List<TransferDestination> transferDestinations(
  ProjectFileNode root,
  List<TreeEntryRef> entries, {
  required bool copy,
  required bool sameProject,
  required String rootLabel,
}) {
  bool allowed(String folder) {
    if (!sameProject) return true;
    final insideSelectedFolder = entries.any((entry) =>
        entry.isFolder &&
        (folder == entry.path || folder.startsWith('${entry.path}/')));
    if (insideSelectedFolder) return false;
    final alreadyThere = entries.every((entry) => parentOf(entry.path) == folder);
    return copy || !alreadyThere;
  }

  final result = <TransferDestination>[];
  if (allowed('')) {
    result.add(TransferDestination(relativePath: '', label: rootLabel, depth: 0));
  }

  void walk(ProjectFileNode node, int depth) {
    for (final child in node.children) {
      if (!child.isFolder) continue;
      if (allowed(child.relativePath)) {
        result.add(TransferDestination(
          relativePath: child.relativePath,
          label: child.name,
          depth: depth,
        ));
      }
      walk(child, depth + 1);
    }
  }

  walk(root, 1);
  return result;
}
