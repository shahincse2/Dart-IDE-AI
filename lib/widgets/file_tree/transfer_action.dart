import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project_model.dart';
import '../../models/tree_entry_ref.dart';
import '../../providers/file_provider.dart';
import '../../providers/tree_selection_provider.dart';
import '../../utils/transfer_destinations.dart';
import 'transfer_dialog.dart';

/// "Copy to…" / "Move to…": asks where to put [chosen] (a project and a
/// folder), does it, and tells the user how it went.
Future<void> transferWithDialog(
  BuildContext context,
  FileProvider files,
  List<TreeEntryRef> chosen, {
  required bool copy,
}) async {
  final current = files.currentProject;
  final entries = withoutNested(chosen);
  if (current == null || entries.isEmpty) return;
  final selection = context.read<TreeSelection>();
  final messenger = ScaffoldMessenger.of(context);

  final target = await showTransferDialog(
    context,
    title: _title(entries, copy: copy),
    projects: _projectsWith(files.projects, current),
    current: current,
    loadTree: files.treeOf,
    destinationsFor: (tree, project) => transferDestinations(
      tree,
      entries,
      copy: copy,
      sameProject: project.id == current.id,
      rootLabel: project.name,
    ),
  );
  if (target == null) return;

  final failed = await files.transferEntries(
    entries,
    target.folder,
    copy: copy,
    toProject: target.project,
  );
  selection.clear();
  messenger.showSnackBar(
    SnackBar(content: Text(_result(entries.length, failed, copy: copy))),
  );
}

/// The known projects, with [current] among them even if the list is stale.
List<ProjectModel> _projectsWith(List<ProjectModel> known, ProjectModel current) {
  return known.any((project) => project.id == current.id)
      ? known
      : [current, ...known];
}

String _title(List<TreeEntryRef> entries, {required bool copy}) {
  final verb = copy ? 'Copy' : 'Move';
  return entries.length == 1
      ? '$verb "${entries.first.name}" to'
      : '$verb ${entries.length} items to';
}

String _result(int total, int failed, {required bool copy}) {
  final verb = copy ? 'Copied' : 'Moved';
  final items = total == 1 ? 'item' : 'items';
  return failed == 0
      ? '$verb $total $items'
      : '$verb ${total - failed} of $total $items';
}
