import 'package:dartlab/models/project_file_node.dart';
import 'package:dartlab/utils/project_tree.dart';
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

void main() {
  final tree = folder('', [
    folder('lib', [file('lib/a.dart'), folder('lib/src', [file('lib/src/b.dart')])]),
    file('main.dart'),
  ]);

  group('treeContainsFile', () {
    test('finds files at any depth', () {
      expect(treeContainsFile(tree, 'main.dart'), isTrue);
      expect(treeContainsFile(tree, 'lib/a.dart'), isTrue);
      expect(treeContainsFile(tree, 'lib/src/b.dart'), isTrue);
    });

    test('a folder path or a missing path is not a file', () {
      expect(treeContainsFile(tree, 'lib'), isFalse);
      expect(treeContainsFile(tree, 'lib/missing.dart'), isFalse);
    });

    test('no tree means no file', () {
      expect(treeContainsFile(null, 'main.dart'), isFalse);
    });
  });

  group('parentOf', () {
    test('a file in the root has the root as its parent', () {
      expect(parentOf('main.dart'), '');
    });

    test('nested paths give their folder', () {
      expect(parentOf('lib/a.dart'), 'lib');
      expect(parentOf('lib/src/b.dart'), 'lib/src');
    });
  });
}
