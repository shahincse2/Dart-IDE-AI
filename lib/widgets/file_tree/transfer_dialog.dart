import 'package:flutter/material.dart';

import '../../models/project_file_node.dart';
import '../../models/project_model.dart';
import '../../utils/constants.dart';
import '../../utils/transfer_destinations.dart';
import 'transfer_folder_list.dart';

/// Where the user chose to put things: a folder of a project.
class TransferTarget {
  const TransferTarget(this.project, this.folder);

  final ProjectModel project;

  /// Relative path of the folder; `` is the project root.
  final String folder;
}

/// Asks where to copy or move to: a project (when there is more than one)
/// and then one of its folders. Returns the choice, or null if cancelled.
///
/// [loadTree] reads a project's files and [destinationsFor] says which of its
/// folders may be chosen, so this dialog knows nothing about either.
Future<TransferTarget?> showTransferDialog(
  BuildContext context, {
  required String title,
  required List<ProjectModel> projects,
  required ProjectModel current,
  required Future<ProjectFileNode> Function(ProjectModel project) loadTree,
  required List<TransferDestination> Function(
    ProjectFileNode tree,
    ProjectModel project,
  ) destinationsFor,
}) {
  return showDialog<TransferTarget>(
    context: context,
    builder: (_) => _TransferDialog(
      title: title,
      projects: projects,
      current: current,
      loadTree: loadTree,
      destinationsFor: destinationsFor,
    ),
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({
    required this.title,
    required this.projects,
    required this.current,
    required this.loadTree,
    required this.destinationsFor,
  });

  final String title;
  final List<ProjectModel> projects;
  final ProjectModel current;
  final Future<ProjectFileNode> Function(ProjectModel project) loadTree;
  final List<TransferDestination> Function(ProjectFileNode, ProjectModel)
      destinationsFor;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late ProjectModel _project = widget.current;
  late Future<List<TransferDestination>> _destinations = _load(_project);

  Future<List<TransferDestination>> _load(ProjectModel project) async {
    final tree = await widget.loadTree(project);
    return widget.destinationsFor(tree, project);
  }

  void _choose(String projectId) {
    final project = widget.projects.firstWhere((p) => p.id == projectId);
    setState(() {
      _project = project;
      _destinations = _load(project);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.symmetric(vertical: AppConstants.spaceSm),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.projects.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _project.id,
                  items: [
                    for (final project in widget.projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(project.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) _choose(id);
                  },
                ),
              ),
            Flexible(
              child: TransferFolderList(
                destinations: _destinations,
                onPick: (folder) => Navigator.pop(
                  context,
                  TransferTarget(_project, folder.relativePath),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
