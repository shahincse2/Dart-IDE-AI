import 'package:dart_ide/models/project_file_node.dart';
import 'package:dart_ide/models/project_model.dart';
import 'package:dart_ide/providers/file_provider.dart';
import 'package:dart_ide/services/file_manager_service.dart';
import 'package:dart_ide/services/session/cursor_memory.dart';
import 'package:dart_ide/services/session/cursor_store.dart';
import 'package:dart_ide/services/session/last_project_store.dart';
import 'package:dart_ide/services/session/project_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Projects that live in a list, with one file each, and no disk.
class _FakeService extends FileManagerService {
  _FakeService(List<String> names)
      : projects = [for (final n in names) _project(n)];

  final List<ProjectModel> projects;

  static ProjectModel _project(String name) =>
      ProjectModel(id: name, name: name, rootPath: '/projects/$name');

  @override
  Future<List<ProjectModel>> listProjects() async => List.of(projects);

  @override
  Future<ProjectModel> renameProject(ProjectModel project, String newName) async {
    final renamed = _project(newName);
    projects
      ..removeWhere((p) => p.id == project.id)
      ..add(renamed);
    return renamed;
  }

  @override
  Future<void> deleteProject(ProjectModel project) async =>
      projects.removeWhere((p) => p.id == project.id);

  @override
  Future<ProjectFileNode> listFileTree(ProjectModel project) async =>
      ProjectFileNode(
        name: project.name,
        type: FileNodeType.folder,
        relativePath: '',
        children: const [
          ProjectFileNode(
            name: 'main.dart',
            type: FileNodeType.file,
            relativePath: 'main.dart',
          ),
        ],
      );

  @override
  Future<String> readFile(ProjectModel project, String relativePath) async => '';

  @override
  Future<void> writeFile(ProjectModel project, String relativePath, String content) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeService service;
  late FileProvider files;
  late CursorMemory cursors;
  late ProjectManager manager;
  var openFilesSaved = 0;

  Future<String?> stored(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  Future<void> start(List<String> names, Map<String, Object> remembered) async {
    SharedPreferences.setMockInitialValues(remembered);
    openFilesSaved = 0;
    service = _FakeService(names);
    files = FileProvider(service: service);
    cursors = CursorMemory(delay: const Duration(milliseconds: 20));
    manager = ProjectManager(
      files: files,
      cursors: cursors,
      saveOpenFiles: () async => openFilesSaved++,
    );
    await files.loadProjects();
  }

  tearDown(() {
    cursors.dispose();
    files.dispose();
  });

  group('rename', () {
    test('the open project keeps its tabs and what is remembered moves with it', () async {
      await start(['Old'], {
        'open_files_Old': 'tabs',
        'last_project_id': 'Old',
      });
      await files.openProject(files.projects.first);
      await cursors.useProject('Old');
      cursors.record('main.dart', 7);

      final renamed = await manager.rename(files.projects.first, 'New');

      expect(renamed.id, 'New');
      expect(files.currentProject?.id, 'New');
      expect(files.openTabs, ['main.dart']);
      expect([for (final p in files.projects) p.name], ['New']);
      expect(openFilesSaved, 1);
      expect(await stored('open_files_New'), 'tabs');
      expect(await stored('open_files_Old'), isNull);
      expect(await LastProjectStore().read(), 'New');
      expect(await CursorStore().read('New'), {'main.dart': 7});
    });

    test('a project that is not open can be renamed while another stays open', () async {
      await start(['Open', 'Other'], {'open_files_Other': 'x'});
      await files.openProject(files.projects.firstWhere((p) => p.id == 'Open'));

      await manager.rename(files.projects.firstWhere((p) => p.id == 'Other'), 'Renamed');

      expect(files.currentProject?.id, 'Open');
      expect(await stored('open_files_Renamed'), 'x');
      expect(await stored('open_files_Other'), isNull);
    });

    test('the same name changes nothing', () async {
      await start(['Same'], {'open_files_Same': 'x'});

      await manager.rename(files.projects.first, 'Same');

      expect(await stored('open_files_Same'), 'x');
    });
  });

  group('delete', () {
    test('the project and everything remembered about it are gone', () async {
      await start(['Gone', 'Kept'], {
        'open_files_Gone': 'a',
        'cursors_Gone': '{}',
        'open_files_Kept': 'b',
        'last_project_id': 'Gone',
      });

      await manager.delete(files.projects.firstWhere((p) => p.id == 'Gone'));

      expect([for (final p in files.projects) p.name], ['Kept']);
      expect(await stored('open_files_Gone'), isNull);
      expect(await stored('cursors_Gone'), isNull);
      expect(await stored('open_files_Kept'), 'b');
      expect(await LastProjectStore().read(), isNull);
    });

    test('deleting the open project closes its tabs', () async {
      await start(['Open'], {});
      await files.openProject(files.projects.first);

      await manager.delete(files.projects.first);

      expect(files.currentProject, isNull);
      expect(files.openTabs, isEmpty);
    });
  });
}
