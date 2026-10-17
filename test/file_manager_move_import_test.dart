import 'dart:io';

import 'package:dartlab/models/project_model.dart';
import 'package:dartlab/services/file_manager_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dirA;
  late Directory dirB;
  late ProjectModel project;
  late ProjectModel other;
  final service = FileManagerService();

  File inA(String relative) => File(p.join(dirA.path, relative));
  File inB(String relative) => File(p.join(dirB.path, relative));

  void write(Directory root, String relative, String content) {
    File(p.join(root.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  setUp(() {
    dirA = Directory.systemTemp.createTempSync('service_a_');
    dirB = Directory.systemTemp.createTempSync('service_b_');
    project = ProjectModel(id: 'a', name: 'a', rootPath: dirA.path);
    other = ProjectModel(id: 'b', name: 'b', rootPath: dirB.path);
    write(dirA, 'main.dart', 'main');
    write(dirA, 'lib/a.dart', 'a');
    write(dirA, 'lib/src/b.dart', 'b');
    Directory(p.join(dirA.path, 'test')).createSync();
    write(dirB, 'keep.dart', 'keep');
  });

  tearDown(() {
    dirA.deleteSync(recursive: true);
    dirB.deleteSync(recursive: true);
  });

  group('importFile', () {
    test('creates the file with its content inside the chosen folder', () async {
      final path = await service.importFile(project, 'lib', 'x.dart', 'void x() {}');

      expect(path, 'lib/x.dart');
      expect(inA('lib/x.dart').readAsStringSync(), 'void x() {}');
    });

    test('adds .dart, and never overwrites an existing file', () async {
      final first = await service.importFile(project, 'lib', 'a', 'new');

      expect(first, 'lib/a (2).dart');
      expect(inA('lib/a.dart').readAsStringSync(), 'a');
      expect(inA('lib/a (2).dart').readAsStringSync(), 'new');
    });

    test('keeps non-ASCII text (Bengali) intact', () async {
      await service.importFile(project, '', 'bn.dart', '// শুভ সকাল');

      expect(inA('bn.dart').readAsStringSync(), '// শুভ সকাল');
    });

    test('createFile still gives the starter content', () async {
      final path = await service.createFile(project, '', 'fresh');

      expect(path, 'fresh.dart');
      expect(inA('fresh.dart').readAsStringSync(), contains('void main()'));
    });
  });

  group('moveEntry (inside a project)', () {
    test('moves a file into a folder', () async {
      final path = await service.moveEntry(project, 'lib/a.dart', 'test', isFolder: false);

      expect(path, 'test/a.dart');
      expect(inA('test/a.dart').readAsStringSync(), 'a');
      expect(inA('lib/a.dart').existsSync(), isFalse);
    });

    test('moves a file to the project root', () async {
      final path = await service.moveEntry(project, 'lib/a.dart', '', isFolder: false);

      expect(path, 'a.dart');
      expect(inA('a.dart').existsSync(), isTrue);
    });

    test('moves a folder together with what is inside it', () async {
      final path = await service.moveEntry(project, 'lib/src', 'test', isFolder: true);

      expect(path, 'test/src');
      expect(inA('test/src/b.dart').readAsStringSync(), 'b');
      expect(Directory(p.join(dirA.path, 'lib/src')).existsSync(), isFalse);
    });

    test('moving into the folder it is already in changes nothing', () async {
      final path = await service.moveEntry(project, 'lib/a.dart', 'lib', isFolder: false);

      expect(path, 'lib/a.dart');
      expect(inA('lib/a.dart').readAsStringSync(), 'a');
      expect(inA('lib/a (2).dart').existsSync(), isFalse);
    });

    test('a taken name gets a numbered suffix instead of being overwritten', () async {
      write(dirA, 'test/a.dart', 'already here');

      final path = await service.moveEntry(project, 'lib/a.dart', 'test', isFolder: false);

      expect(path, 'test/a (2).dart');
      expect(inA('test/a.dart').readAsStringSync(), 'already here');
      expect(inA('test/a (2).dart').readAsStringSync(), 'a');
    });

    test('a folder cannot be moved into itself or below itself', () async {
      expect(
        () => service.moveEntry(project, 'lib', 'lib', isFolder: true),
        throwsArgumentError,
      );
      expect(
        () => service.moveEntry(project, 'lib', 'lib/src', isFolder: true),
        throwsArgumentError,
      );
      expect(inA('lib/a.dart').existsSync(), isTrue);
    });
  });

  group('moveEntry (to another project)', () {
    test('moves a file into the other project and removes it here', () async {
      final path = await service.moveEntry(
        project, 'lib/a.dart', '', isFolder: false, toProject: other);

      expect(path, 'a.dart');
      expect(inB('a.dart').readAsStringSync(), 'a');
      expect(inA('lib/a.dart').existsSync(), isFalse);
    });

    test('moves a folder with everything in it', () async {
      final path = await service.moveEntry(
        project, 'lib', '', isFolder: true, toProject: other);

      expect(path, 'lib');
      expect(inB('lib/src/b.dart').readAsStringSync(), 'b');
      expect(Directory(p.join(dirA.path, 'lib')).existsSync(), isFalse);
    });

    test('a taken name over there is not overwritten', () async {
      write(dirB, 'a.dart', 'theirs');

      final path = await service.moveEntry(
        project, 'lib/a.dart', '', isFolder: false, toProject: other);

      expect(path, 'a (2).dart');
      expect(inB('a.dart').readAsStringSync(), 'theirs');
    });

    test('a folder may go to a folder of the same name in the other project', () async {
      write(dirB, 'lib/x.dart', 'x');

      final path = await service.moveEntry(
        project, 'lib', 'lib', isFolder: true, toProject: other);

      expect(path, 'lib/lib');
      expect(inB('lib/lib/a.dart').existsSync(), isTrue);
    });
  });

  group('copyEntry', () {
    test('copies a file and leaves the original', () async {
      final path = await service.copyEntry(project, 'lib/a.dart', 'test', isFolder: false);

      expect(path, 'test/a.dart');
      expect(inA('test/a.dart').readAsStringSync(), 'a');
      expect(inA('lib/a.dart').readAsStringSync(), 'a');
    });

    test('copying into the same folder makes a numbered duplicate', () async {
      final path = await service.copyEntry(project, 'lib/a.dart', 'lib', isFolder: false);

      expect(path, 'lib/a (2).dart');
      expect(inA('lib/a (2).dart').readAsStringSync(), 'a');
      expect(inA('lib/a.dart').readAsStringSync(), 'a');
    });

    test('copies a folder with everything in it, leaving the original', () async {
      final path = await service.copyEntry(project, 'lib', 'test', isFolder: true);

      expect(path, 'test/lib');
      expect(inA('test/lib/a.dart').readAsStringSync(), 'a');
      expect(inA('test/lib/src/b.dart').readAsStringSync(), 'b');
      expect(inA('lib/src/b.dart').readAsStringSync(), 'b');
    });

    test('a folder cannot be copied into itself or below itself', () async {
      expect(
        () => service.copyEntry(project, 'lib', 'lib', isFolder: true),
        throwsArgumentError,
      );
      expect(
        () => service.copyEntry(project, 'lib', 'lib/src', isFolder: true),
        throwsArgumentError,
      );
    });

    test('copies into another project', () async {
      final file = await service.copyEntry(
        project, 'main.dart', '', isFolder: false, toProject: other);
      final folder = await service.copyEntry(
        project, 'lib', '', isFolder: true, toProject: other);

      expect(file, 'main.dart');
      expect(folder, 'lib');
      expect(inB('main.dart').readAsStringSync(), 'main');
      expect(inB('lib/src/b.dart').readAsStringSync(), 'b');
      expect(inA('main.dart').existsSync(), isTrue);
      expect(inB('keep.dart').readAsStringSync(), 'keep');
    });

    test('a copy never overwrites what is already there', () async {
      write(dirA, 'test/a.dart', 'already here');

      final path = await service.copyEntry(project, 'lib/a.dart', 'test', isFolder: false);

      expect(path, 'test/a (2).dart');
      expect(inA('test/a.dart').readAsStringSync(), 'already here');
    });
  });
}
