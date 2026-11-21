import 'dart:io';

import 'package:dart_ide/models/project_model.dart';
import 'package:dart_ide/models/tree_entry_ref.dart';
import 'package:dart_ide/providers/file_provider.dart';
import 'package:dart_ide/utils/constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _starter = 'void main() {\n  \n}\n';

/// Waits long enough for an autosave to have happened.
Future<void> afterAutoSave() => Future<void>.delayed(
      AppConstants.autoSaveDebounce + const Duration(milliseconds: 200),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late FileProvider files;
  late ProjectModel project;

  String read(String relativePath) =>
      File(p.join(project.rootPath, relativePath)).readAsStringSync();
  bool exists(String relativePath) =>
      File(p.join(project.rootPath, relativePath)).existsSync();

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('dart_ide_files_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      return call.method == 'getApplicationDocumentsDirectory'
          ? docs.path
          : null;
    });
    files = FileProvider();
    project = await files.createProject('Demo');
    await files.openProject(project);
  });

  tearDown(() {
    files.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    docs.deleteSync(recursive: true);
  });

  group('projects', () {
    test('a taken name gets a number, and main.dart opens by itself', () async {
      final second = await files.createProject('Demo');

      expect(second.name, 'Demo (2)');
      expect(files.openTabs, ['main.dart']);
      expect(files.activeTab, 'main.dart');
      expect(read('main.dart'), _starter);
    });

    test('deleting the open project closes everything', () async {
      await files.deleteProject(project);

      expect(files.currentProject, isNull);
      expect(files.openTabs, isEmpty);
    });
  });

  group('files and folders', () {
    test('a new file opens, and the tree lists folders first', () async {
      await files.createFolder('', 'lib');
      await files.createFile('', 'util');

      expect(files.activeTab, 'util.dart');
      final names = [for (final n in files.fileTree!.children) n.name];
      expect(names, ['lib', 'main.dart', 'util.dart']);
    });

    test('a file in a folder says which folder is active', () async {
      await files.createFolder('', 'lib');
      await files.createFile('lib', 'a');

      expect(files.activeTab, 'lib/a.dart');
      expect(files.activeFolder, 'lib');
    });

    test('deleting a folder closes the tabs inside it', () async {
      await files.createFolder('', 'lib');
      await files.createFile('lib', 'a');

      await files.deleteEntry('lib', isFolder: true);

      expect(files.openTabs, ['main.dart']);
      expect(Directory(p.join(project.rootPath, 'lib')).existsSync(), isFalse);
    });
  });

  group('saving', () {
    test('typing is saved after the delay, not before', () async {
      files.scheduleAutoSave('main.dart', 'int x = 1;');

      expect(files.isDirty('main.dart'), isTrue);
      expect(read('main.dart'), _starter);
      await afterAutoSave();
      expect(read('main.dart'), 'int x = 1;');
      expect(files.isDirty('main.dart'), isFalse);
    });

    test('flushAllPendingSaves writes at once', () async {
      files.scheduleAutoSave('main.dart', '// edited');

      await files.flushAllPendingSaves();

      expect(read('main.dart'), '// edited');
    });

    test('closing a tab can discard or save the edit', () async {
      await files.createFile('', 'a');
      files.scheduleAutoSave('a.dart', 'discarded');
      await files.closeTab('a.dart', flush: false);
      expect(read('a.dart'), _starter);

      files.openFile('a.dart');
      files.scheduleAutoSave('a.dart', 'kept');
      await files.closeTab('a.dart', flush: true);
      expect(read('a.dart'), 'kept');
    });
  });

  group('renaming, moving and copying', () {
    test('a renamed file keeps its tab', () async {
      await files.createFile('', 'util');

      await files.renameEntry('util.dart', 'helpers', isFolder: false);

      expect(files.openTabs, ['main.dart', 'helpers.dart']);
      expect(files.activeTab, 'helpers.dart');
      expect(exists('util.dart'), isFalse);
    });

    test(
        'renaming a file whose edit is still waiting does not bring the old one back',
        () async {
      await files.createFile('', 'x');
      files.scheduleAutoSave('x.dart', 'my edit');

      await files.renameEntry('x.dart', 'y', isFolder: false);
      await afterAutoSave();

      expect(exists('x.dart'), isFalse);
      expect(read('y.dart'), 'my edit');
      expect(files.isDirty('y.dart'), isFalse);
    });

    test('a moved file keeps its tab and its waiting edit', () async {
      await files.createFolder('', 'lib');
      await files.createFile('', 'a');
      files.scheduleAutoSave('a.dart', 'moved text');

      await files.moveEntry('a.dart', 'lib', isFolder: false);
      await afterAutoSave();

      expect(files.activeTab, 'lib/a.dart');
      expect(read('lib/a.dart'), 'moved text');
      expect(exists('a.dart'), isFalse);
    });

    test('a copy in the same folder gets a number; tabs stay', () async {
      await files.createFile('', 'a');

      await files.copyEntry('a.dart', '', isFolder: false);

      expect(exists('a (2).dart'), isTrue);
      expect(files.openTabs, ['main.dart', 'a.dart']);
    });

    test('moving to another project closes the tab', () async {
      final other = await files.createProject('Other');
      await files.createFile('', 'a');

      await files.moveEntry('a.dart', '', isFolder: false, toProject: other);

      expect(files.openTabs, ['main.dart']);
      expect(File(p.join(other.rootPath, 'a.dart')).existsSync(), isTrue);
    });

    test('transferring many counts the ones that fail', () async {
      await files.createFolder('', 'lib');

      final failed = await files.transferEntries(
        const [
          TreeEntryRef('lib', isFolder: true),
          TreeEntryRef('main.dart', isFolder: false),
        ],
        'lib',
        copy: true,
      );

      expect(failed, 1); // a folder cannot be copied into itself
      expect(exists('lib/main.dart'), isTrue);
    });
  });
}
