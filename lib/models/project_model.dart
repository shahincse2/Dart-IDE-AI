/// A Dart project on disk. Deliberately minimal: a project IS a folder
/// under `<appDocuments>/projects/`, identified by that folder's name.
/// No separate metadata store — listing projects means listing that
/// directory's subfolders (see [FileManagerService.listProjects]).
class ProjectModel {
  /// The folder name, also used as the stable identifier.
  final String id;
  final String name;
  final String rootPath;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.rootPath,
  });
}
