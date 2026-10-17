import 'package:dartlab/models/project_file_node.dart';
import 'package:dartlab/models/tree_entry_ref.dart';
import 'package:dartlab/utils/transfer_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectFileNode folder(String path, [List<ProjectFileNode> children = const []]) =>
    ProjectFileNode(
      name: path.split('/').last,
      type: FileNodeType.folder,
      relativePath: path,
      children: children,
    );

ProjectFileNode file(String path) => ProjectFileNode(
      name: path.split('/').last,
      type: FileNodeType.file,
      relativePath: path,
    );

TreeEntryRef fileRef(String path) => TreeEntryRef(path, isFolder: false);
TreeEntryRef folderRef(String path) => TreeEntryRef(path, isFolder: true);

void main() {
  final tree = folder('', [
    folder('lib', [folder('lib/src'), file('lib/a.dart')]),
    folder('test'),
    file('main.dart'),
  ]);

  List<String> paths(
    List<TreeEntryRef> entries, {
    bool copy = false,
    bool sameProject = true,
  }) =>
      transferDestinations(
        tree,
        entries,
        copy: copy,
        sameProject: sameProject,
        rootLabel: 'loop',
      ).map((d) => d.relativePath).toList();

  group('transferDestinations (moving)', () {
    test('a file in the root can go to every folder but not the root', () {
      expect(paths([fileRef('main.dart')]), ['lib', 'lib/src', 'test']);
    });

    test('a file in a folder can go anywhere but that folder', () {
      expect(paths([fileRef('lib/a.dart')]), ['', 'lib/src', 'test']);
    });

    test('a folder cannot go into itself or below itself', () {
      expect(paths([folderRef('lib')]), ['test']);
    });

    test('several entries: only the folder holding all of them is left out', () {
      expect(
        paths([fileRef('main.dart'), fileRef('lib/a.dart')]),
        ['', 'lib', 'lib/src', 'test'],
      );
      expect(
        paths([fileRef('lib/a.dart'), folderRef('lib/src')]),
        ['', 'test'],
      );
    });

    test('a selected folder rules out itself and below, whatever else is selected', () {
      expect(paths([folderRef('lib'), fileRef('main.dart')]), ['test']);
    });
  });

  group('transferDestinations (copying)', () {
    test('copying into the folder it is already in (a duplicate) is allowed', () {
      expect(
        paths([fileRef('lib/a.dart')], copy: true),
        ['', 'lib', 'lib/src', 'test'],
      );
    });

    test('a folder still cannot be copied into itself', () {
      expect(paths([folderRef('lib')], copy: true), ['', 'test']);
    });
  });

  group('transferDestinations (another project)', () {
    test('every folder is allowed, even one with the same path as a selected folder', () {
      expect(
        paths([folderRef('lib')], sameProject: false),
        ['', 'lib', 'lib/src', 'test'],
      );
    });

    test('the root is shown under the project name, folders are indented', () {
      final all = transferDestinations(
        tree,
        [fileRef('x.dart')],
        copy: true,
        sameProject: false,
        rootLabel: 'other',
      );

      expect(all.first.label, 'other');
      expect(all.map((d) => d.depth).toList(), [0, 1, 2, 1]);
    });
  });

  group('withoutNested', () {
    test('an entry inside a selected folder travels with it', () {
      final result = withoutNested([
        folderRef('lib'),
        fileRef('lib/a.dart'),
        folderRef('lib/src'),
        fileRef('main.dart'),
      ]);

      expect(result, [folderRef('lib'), fileRef('main.dart')]);
    });

    test('repeated entries are kept once', () {
      expect(
        withoutNested([fileRef('a.dart'), fileRef('a.dart')]),
        [fileRef('a.dart')],
      );
    });

    test('a folder name that merely starts the same is not a parent', () {
      expect(
        withoutNested([folderRef('lib'), fileRef('library.dart')]),
        [folderRef('lib'), fileRef('library.dart')],
      );
    });
  });
}
