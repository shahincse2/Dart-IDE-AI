import 'dart:io';

import 'package:dartlab/models/project_model.dart';
import 'package:dartlab/models/tree_entry_ref.dart';
import 'package:dartlab/providers/file_provider.dart';
import 'package:dartlab/services/file_manager_service.dart';
import 'package:dartlab/utils/project_tree.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dirA;
  late Directory dirB;
  late ProjectModel other;
  late FileProvider files;

  File inA(String relative) => File(p.join(dirA.path, relative));
  File inB(String relative) => File(p.join(dirB.path, relative));

  void write(Directory root, String relative, String content) {
    File(p.join(root.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  setUp(() async {
    dirA = Directory.systemTemp.createTempSync('provider_a_');
    dirB = Directory.systemTemp.createTempSync('provider_b_');
    write(dirA, 'main.dart', 'void main() {}');
    write(dirA, 'lib/a.dart', 'a');
    write(dirA, 'lib/src/b.dart', 'b');
    Directory(p.join(dirA.path, 'test')).createSync();
    write(dirB, 'keep.dart', 'keep');
    other = ProjectModel(id: 'b', name: 'b', rootPath: dirB.path);

    files = FileProvider(service: FileManagerService());
    await files.openProject(ProjectModel(id: 'a', name: 'a', rootPath: dirA.path));
  });

  tearDown(() {
    files.dispose();
    dirA.deleteSync(recursive: true);
    dirB.deleteSync(recursive: true);
  });

  group('activeFolder', () {
    test('is the folder of the active file, or the root', () {
      files.openFile('lib/src/b.dart');
      expect(files.activeFolder, 'lib/src');

      files.openFile('main.dart');
      expect(files.activeFolder, '');
    });
  });

  group('importFile', () {
    test('adds the file to the chosen folder, with its content, and opens it', () async {
      await files.importFile('imported.dart', '// শুভ', parentRelativePath: 'lib');

      expect(files.activeTab, 'lib/imported.dart');
      expect(inA('lib/imported.dart').readAsStringSync(), '// শুভ');
      expect(treeContainsFile(files.fileTree, 'lib/imported.dart'), isTrue);
    });

    test('goes to the project root when no folder is given', () async {
      await files.importFile('top.dart', 'x');

      expect(files.activeTab, 'top.dart');
    });
  });

  group('moveEntry (inside the project)', () {
    test('an open file follows its move and stays active', () async {
      files.openFile('lib/a.dart');

      await files.moveEntry('lib/a.dart', 'test', isFolder: false);

      expect(files.openTabs, contains('test/a.dart'));
      expect(files.openTabs, isNot(contains('lib/a.dart')));
      expect(files.activeTab, 'test/a.dart');
    });

    test('tabs below a moved folder follow it', () async {
      files.openFile('lib/src/b.dart');

      await files.moveEntry('lib/src', 'test', isFolder: true);

      expect(files.openTabs, contains('test/src/b.dart'));
      expect(files.activeTab, 'test/src/b.dart');
    });

    test('unsaved edits are written before the move, not lost or left behind', () async {
      files.openFile('lib/a.dart');
      files.scheduleAutoSave('lib/a.dart', 'edited');

      await files.moveEntry('lib/a.dart', 'test', isFolder: false);

      expect(inA('test/a.dart').readAsStringSync(), 'edited');
      expect(inA('lib/a.dart').existsSync(), isFalse);
      expect(files.isDirty('test/a.dart'), isFalse);
    });

    test('a taken name gives the moved file a numbered name, and the tab follows', () async {
      write(dirA, 'test/a.dart', 'already here');
      files.openFile('lib/a.dart');

      await files.moveEntry('lib/a.dart', 'test', isFolder: false);

      expect(files.activeTab, 'test/a (2).dart');
      expect(inA('test/a.dart').readAsStringSync(), 'already here');
    });

    test('moving into the same folder leaves everything as it was', () async {
      files.openFile('lib/a.dart');

      await files.moveEntry('lib/a.dart', 'lib', isFolder: false);

      expect(files.activeTab, 'lib/a.dart');
      expect(inA('lib/a.dart').readAsStringSync(), 'a');
    });

    test('the file tree shows the new place', () async {
      await files.moveEntry('lib/a.dart', 'test', isFolder: false);

      expect(treeContainsFile(files.fileTree, 'test/a.dart'), isTrue);
      expect(treeContainsFile(files.fileTree, 'lib/a.dart'), isFalse);
    });
  });

  group('copyEntry', () {
    test('copies and leaves the original and its tab alone', () async {
      files.openFile('lib/a.dart');

      await files.copyEntry('lib/a.dart', 'test', isFolder: false);

      expect(inA('test/a.dart').existsSync(), isTrue);
      expect(inA('lib/a.dart').existsSync(), isTrue);
      expect(files.activeTab, 'lib/a.dart');
      expect(treeContainsFile(files.fileTree, 'test/a.dart'), isTrue);
    });

    test('the copy contains unsaved edits too', () async {
      files.openFile('lib/a.dart');
      files.scheduleAutoSave('lib/a.dart', 'edited');

      await files.copyEntry('lib/a.dart', 'test', isFolder: false);

      expect(inA('test/a.dart').readAsStringSync(), 'edited');
    });
  });

  group('to another project', () {
    test('a moved file leaves this project and its tab closes', () async {
      files.openFile('lib/a.dart');

      await files.moveEntry('lib/a.dart', '', isFolder: false, toProject: other);

      expect(inB('a.dart').readAsStringSync(), 'a');
      expect(inA('lib/a.dart').existsSync(), isFalse);
      expect(files.openTabs, isNot(contains('lib/a.dart')));
      expect(treeContainsFile(files.fileTree, 'lib/a.dart'), isFalse);
    });

    test('unsaved edits go along with a moved file', () async {
      files.openFile('lib/a.dart');
      files.scheduleAutoSave('lib/a.dart', 'edited');

      await files.moveEntry('lib/a.dart', '', isFolder: false, toProject: other);

      expect(inB('a.dart').readAsStringSync(), 'edited');
      expect(inA('lib/a.dart').existsSync(), isFalse);
    });

    test('a copy keeps the original and its tab', () async {
      files.openFile('lib/a.dart');

      await files.copyEntry('lib/a.dart', '', isFolder: false, toProject: other);

      expect(inB('a.dart').readAsStringSync(), 'a');
      expect(inA('lib/a.dart').existsSync(), isTrue);
      expect(files.openTabs, contains('lib/a.dart'));
    });

    test('treeOf reads any project, not only the open one', () async {
      final tree = await files.treeOf(other);

      expect(treeContainsFile(tree, 'keep.dart'), isTrue);
    });
  });

  group('transferEntries', () {
    test('moves several entries at once', () async {
      final failed = await files.transferEntries(
        const [
          TreeEntryRef('lib/a.dart', isFolder: false),
          TreeEntryRef('lib/src', isFolder: true),
        ],
        'test',
        copy: false,
      );

      expect(failed, 0);
      expect(inA('test/a.dart').existsSync(), isTrue);
      expect(inA('test/src/b.dart').existsSync(), isTrue);
      expect(inA('lib/a.dart').existsSync(), isFalse);
    });

    test('copies several entries into another project', () async {
      final failed = await files.transferEntries(
        const [
          TreeEntryRef('main.dart', isFolder: false),
          TreeEntryRef('lib', isFolder: true),
        ],
        '',
        copy: true,
        toProject: other,
      );

      expect(failed, 0);
      expect(inB('main.dart').existsSync(), isTrue);
      expect(inB('lib/src/b.dart').existsSync(), isTrue);
      expect(inA('lib/src/b.dart').existsSync(), isTrue);
    });

    test('one that cannot be done is counted and the others still happen', () async {
      final failed = await files.transferEntries(
        const [
          TreeEntryRef('main.dart', isFolder: false),
          TreeEntryRef('lib', isFolder: true), // into itself: not possible
        ],
        'lib/src',
        copy: false,
      );

      expect(failed, 1);
      expect(inA('lib/src/main.dart').existsSync(), isTrue);
      expect(inA('lib/a.dart').existsSync(), isTrue);
    });
  });
}
