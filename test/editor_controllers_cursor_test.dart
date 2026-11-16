import 'package:dartlab/models/project_file_node.dart';
import 'package:dartlab/models/project_model.dart';
import 'package:dartlab/providers/file_provider.dart';
import 'package:dartlab/providers/settings_provider.dart';
import 'package:dartlab/screens/editor/editor_controllers.dart';
import 'package:dartlab/services/file_manager_service.dart';
import 'package:dartlab/services/session/cursor_memory.dart';
import 'package:dartlab/services/session/cursor_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _project = ProjectModel(id: 'Demo', name: 'Demo', rootPath: '/demo');
const _text = 'void main() {\n  print(1);\n}\n';

/// A service with one file and no disk.
class _FakeService extends FileManagerService {
  @override
  Future<List<ProjectModel>> listProjects() async => [_project];

  @override
  Future<ProjectFileNode> listFileTree(ProjectModel project) async =>
      const ProjectFileNode(
        name: 'Demo',
        type: FileNodeType.folder,
        relativePath: '',
        children: [
          ProjectFileNode(
            name: 'main.dart',
            type: FileNodeType.file,
            relativePath: 'main.dart',
          ),
        ],
      );

  @override
  Future<String> readFile(ProjectModel project, String relativePath) async =>
      _text;

  @override
  Future<void> writeFile(
    ProjectModel project,
    String relativePath,
    String content,
  ) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileProvider files;
  late CursorMemory cursors;
  late EditorControllers editors;

  Future<void> openWithRememberedCursor(int? cursor) async {
    SharedPreferences.setMockInitialValues({
      if (cursor != null) 'cursors_Demo': '{"main.dart":$cursor}',
    });
    files = FileProvider(service: _FakeService());
    cursors = CursorMemory(delay: const Duration(milliseconds: 20));
    editors = EditorControllers(
      files: files,
      cursors: cursors,
      settings: () => SettingsProvider(),
      isAlive: () => true,
      onChanged: () {},
    );
    await files.openProject(_project);
    await editors.sync();
  }

  tearDown(() {
    editors.dispose();
    cursors.dispose();
    files.dispose();
  });

  group('EditorControllers and the remembered cursor', () {
    test('a file opens with its cursor where it was left', () async {
      await openWithRememberedCursor(20);

      expect(editors.of('main.dart')!.selection.baseOffset, 20);
    });

    test('a file never opened before starts at the top', () async {
      await openWithRememberedCursor(null);

      expect(editors.of('main.dart')!.selection.baseOffset, 0);
    });

    test(
        'a remembered place beyond the end of the file is brought back inside it',
        () async {
      await openWithRememberedCursor(9999);

      expect(editors.of('main.dart')!.selection.baseOffset, _text.length);
    });

    test('moving the cursor is remembered', () async {
      await openWithRememberedCursor(null);

      editors.of('main.dart')!.selection =
          const TextSelection.collapsed(offset: 15);
      await cursors.flush();

      expect(await CursorStore().read('Demo'), {'main.dart': 15});
    });
  });
}
