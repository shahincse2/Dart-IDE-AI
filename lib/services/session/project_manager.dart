import '../../models/project_model.dart';
import '../../providers/file_provider.dart';
import 'cursor_memory.dart';
import 'project_data_store.dart';

/// Renaming and deleting projects: the folder, and everything the app
/// remembers about the project (open files, cursors, being the last project).
class ProjectManager {
  ProjectManager({
    required FileProvider files,
    required CursorMemory cursors,
    required Future<void> Function() saveOpenFiles,
    ProjectDataStore? data,
  })  : _files = files,
        _cursors = cursors,
        _saveOpenFiles = saveOpenFiles,
        _data = data ?? ProjectDataStore();

  final FileProvider _files;
  final CursorMemory _cursors;
  final Future<void> Function() _saveOpenFiles;
  final ProjectDataStore _data;

  /// Renames [project]; returns it with the name it really got (a number is
  /// added when the name is taken). If it is the open project its tabs stay
  /// open.
  Future<ProjectModel> rename(ProjectModel project, String newName) async {
    // What is remembered is written under the OLD name; it moves afterwards.
    await _saveOpenFiles();
    await _cursors.flush();

    final renamed = await _files.renameProject(project, newName);
    if (renamed.id != project.id) {
      await _data.rename(project.id, renamed.id);
      _cursors.renameProject(project.id, renamed.id);
    }
    return renamed;
  }

  /// Deletes [project] with all its files, for good.
  Future<void> delete(ProjectModel project) async {
    await _files.deleteProject(project);
    _cursors.forgetProject(project.id);
    await _data.forget(project.id);
  }
}
