import 'package:dartlab/models/tree_entry_ref.dart';
import 'package:dartlab/providers/tree_selection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const a = TreeEntryRef('lib/a.dart', isFolder: false);
const lib = TreeEntryRef('lib', isFolder: true);

void main() {
  group('TreeEntryRef', () {
    test('has the name of the last path part', () {
      expect(a.name, 'a.dart');
      expect(const TreeEntryRef('main.dart', isFolder: false).name, 'main.dart');
    });

    test('two refs to the same thing are equal', () {
      expect(const TreeEntryRef('lib', isFolder: true), lib);
      expect(const TreeEntryRef('lib', isFolder: false), isNot(lib));
    });
  });

  group('TreeSelection', () {
    test('nothing is selected at first', () {
      final selection = TreeSelection();

      expect(selection.isActive('p'), isFalse);
      expect(selection.entriesFor('p'), isEmpty);
    });

    test('begin starts a selection with one entry', () {
      final selection = TreeSelection()..begin('p', a);

      expect(selection.isActive('p'), isTrue);
      expect(selection.isSelected('p', 'lib/a.dart'), isTrue);
      expect(selection.countFor('p'), 1);
    });

    test('toggle ticks and unticks, in the order ticked', () {
      final selection = TreeSelection()..begin('p', a);

      selection.toggle(lib);
      expect(selection.entriesFor('p'), [a, lib]);

      selection.toggle(a);
      expect(selection.entriesFor('p'), [lib]);
    });

    test('unticking the last entry ends the selection', () {
      final selection = TreeSelection()..begin('p', a);

      selection.toggle(a);

      expect(selection.isActive('p'), isFalse);
    });

    test('begin replaces an earlier selection', () {
      final selection = TreeSelection()..begin('p', a);

      selection.begin('p', lib);

      expect(selection.entriesFor('p'), [lib]);
    });

    test('the selection counts as empty for another project', () {
      final selection = TreeSelection()..begin('p', a);

      expect(selection.isActive('q'), isFalse);
      expect(selection.isSelected('q', 'lib/a.dart'), isFalse);
      expect(selection.entriesFor('q'), isEmpty);
    });

    test('clear empties it and tells the listeners once', () {
      final selection = TreeSelection()..begin('p', a);
      var heard = 0;
      selection.addListener(() => heard++);

      selection.clear();
      selection.clear(); // nothing left: no second notification

      expect(selection.isActive('p'), isFalse);
      expect(heard, 1);
    });
  });
}
