import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_model.dart';
import '../providers/file_provider.dart';
import '../services/open_files_tracker.dart';
import '../services/session/cursor_memory.dart';
import '../services/session/project_manager.dart';
import 'name_dialog.dart';

ProjectManager _managerFor(BuildContext context) => ProjectManager(
      files: context.read<FileProvider>(),
      cursors: context.read<CursorMemory>(),
      saveOpenFiles: context.read<OpenFilesTracker>().flush,
    );

/// Asks for a new name and renames [project]; says what happened.
Future<void> renameProjectFlow(
  BuildContext context,
  ProjectModel project,
) async {
  final manager = _managerFor(context);
  final messenger = ScaffoldMessenger.of(context);

  final name = await showNameDialog(
    context,
    title: 'Rename project',
    initialValue: project.name,
    hint: 'Project name',
    confirmLabel: 'Rename',
  );
  if (name == null || name.isEmpty || name == project.name) return;

  try {
    final renamed = await manager.rename(project, name);
    messenger.showSnackBar(
      SnackBar(content: Text('Renamed to "${renamed.name}"')),
    );
  } on Exception {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not rename the project')),
    );
  }
}

/// Asks to be sure, then deletes [project] with all its files.
Future<void> deleteProjectFlow(
  BuildContext context,
  ProjectModel project,
) async {
  final manager = _managerFor(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${project.name}"?'),
      content: const Text(
        'All the files in this project will be deleted. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await manager.delete(project);
    messenger.showSnackBar(
      SnackBar(content: Text('Deleted "${project.name}"')),
    );
  } on Exception {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not delete the project')),
    );
  }
}
