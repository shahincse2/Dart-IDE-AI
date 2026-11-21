import 'package:flutter/material.dart';

/// What can be done with a project from the project list.
enum ProjectAction { rename, delete }

/// The ⋮ menu of a project in the project list.
class ProjectMenu extends StatelessWidget {
  const ProjectMenu({super.key, required this.onSelected});

  final ValueChanged<ProjectAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProjectAction>(
      tooltip: 'Project options',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: ProjectAction.rename,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: ProjectAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
