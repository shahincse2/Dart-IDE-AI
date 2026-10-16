import 'package:dartlab/providers/folder_expansion_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FolderExpansion', () {
    test('folders are open until the user closes them', () {
      final state = FolderExpansion();

      expect(state.isExpanded('loop/lib'), isTrue);
    });

    test('toggling closes a folder, toggling again opens it', () {
      final state = FolderExpansion();

      state.toggle('loop/lib');
      expect(state.isExpanded('loop/lib'), isFalse);

      state.toggle('loop/lib');
      expect(state.isExpanded('loop/lib'), isTrue);
    });

    test('folders are independent of each other', () {
      final state = FolderExpansion();

      state.toggle('loop/lib');

      expect(state.isExpanded('loop/lib'), isFalse);
      expect(state.isExpanded('loop/test'), isTrue);
      expect(state.isExpanded('other/lib'), isTrue);
    });

    test('listeners hear about every toggle', () {
      final state = FolderExpansion();
      var heard = 0;
      state.addListener(() => heard++);

      state.toggle('a');
      state.toggle('a');

      expect(heard, 2);
    });
  });
}
