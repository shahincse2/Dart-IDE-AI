import 'package:dart_ide/models/project_file_node.dart';
import 'package:dart_ide/models/project_model.dart';
import 'package:dart_ide/providers/file_provider.dart';
import 'package:dart_ide/services/file_manager_service.dart';
import 'package:dart_ide/services/open_files_tracker.dart';
import 'package:dart_ide/services/session/cursor_memory.dart';
import 'package:dart_ide/services/session/last_project_store.dart';
import 'package:dart_ide/widgets/session_keeper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _demo = ProjectModel(id: 'Demo', name: 'Demo', rootPath: '/demo');

/// A service with one project holding one file, and no disk.
class _FakeService extends FileManagerService {
  final Map<String, String> files = {'main.dart': 'void main() {}'};

  @override
  Future<List<ProjectModel>> listProjects() async => [_demo];

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
      files[relativePath] ?? '';

  @override
  Future<void> writeFile(
    ProjectModel project,
    String relativePath,
    String content,
  ) async {
    files[relativePath] = content;
  }
}

void main() {
  late _FakeService service;
  late FileProvider files;

  Future<void> start(
      WidgetTester tester, Map<String, Object> remembered) async {
    SharedPreferences.setMockInitialValues(remembered);
    service = _FakeService();
    files = FileProvider(service: service);
    final tracker = OpenFilesTracker(
      changes: files,
      projectId: () => files.currentProject?.id,
      openTabs: () => files.openTabs,
      activeFile: () => files.activeTab,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FileProvider>.value(value: files),
          Provider<OpenFilesTracker>.value(value: tracker),
          Provider<CursorMemory>.value(value: CursorMemory()),
        ],
        child: MaterialApp(
          home: SessionKeeper(
            editorBuilder: (_) => const Scaffold(body: Text('EDITOR')),
            child: const Scaffold(body: Text('HOME')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lets the pending timers (saving the open tabs) run out.
  Future<void> finish(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 2));

  group('SessionKeeper', () {
    testWidgets('with nothing remembered it shows the first screen',
        (tester) async {
      await start(tester, {});

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('EDITOR'), findsNothing);
      expect(files.currentProject, isNull);
      await finish(tester);
    });

    testWidgets('it reopens the project that was open last, in the editor',
        (tester) async {
      await start(tester, {'last_project_id': 'Demo'});

      expect(find.text('EDITOR'), findsOneWidget);
      expect(files.currentProject?.id, 'Demo');
      expect(files.openTabs, ['main.dart']);
      await finish(tester);
    });

    testWidgets('a remembered project that is gone is ignored', (tester) async {
      await start(tester, {'last_project_id': 'Gone'});

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('EDITOR'), findsNothing);
      await finish(tester);
    });

    testWidgets('the project that gets opened is remembered', (tester) async {
      await start(tester, {});

      await files.openProject(_demo);
      await tester.pump();

      final remembered = await tester.runAsync(() => LastProjectStore().read());
      expect(remembered, 'Demo');
      await finish(tester);
    });

    testWidgets('going to the background saves what is waiting',
        (tester) async {
      await start(tester, {'last_project_id': 'Demo'});
      files.scheduleAutoSave('main.dart', 'int typed = 1;');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(service.files['main.dart'], 'int typed = 1;');
      await finish(tester);
    });
  });
}
