import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/project_model.dart';
import '../../providers/file_provider.dart';
import '../../services/open_files_store.dart';
import '../../services/open_files_tracker.dart';
import '../../services/restore_open_files.dart';

/// Opens [project] the way the project list does: the state of the project
/// being left is saved, then the project opens with the tabs it had last time.
Future<void> openProjectWithMemory(
  BuildContext context,
  ProjectModel project,
) async {
  final files = context.read<FileProvider>();
  final tracker = context.read<OpenFilesTracker>();
  // Save the state of the project we are leaving, then read what was
  // remembered for this one BEFORE openProject: it opens the default
  // file, which changes what is remembered.
  await tracker.flush();
  final remembered = await OpenFilesStore().read(project.id);
  await files.openProject(project);
  await restoreOpenFiles(files, remembered);
}
