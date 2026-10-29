import 'package:dartlab/utils/fold_model.dart';
import 'package:flutter_test/flutter_test.dart';

const block = 'void main() {\n  a();\n  b();\n}\n';

FoldModel synced([String text = block]) => FoldModel()..sync(text, () => const []);

void main() {
  group('FoldModel', () {
    test('finds the region of a block', () {
      expect(synced().regions.length, 1);
    });

    test('nothing is folded at first', () {
      final model = synced();

      expect(model.hasFolded, isFalse);
      expect(model.hiddenLines, isEmpty);
      expect(model.hiddenSignature, '');
    });

    test('foldAll hides the lines between the braces', () {
      final model = synced();

      expect(model.foldAll(), isTrue);

      expect(model.hiddenLines.single.first, 1);
      expect(model.hiddenLines.single.last, 2);
      expect(model.hiddenSignature, '1-2');
      expect(model.foldedStarts, [0]);
    });

    test('the hidden characters are those two lines', () {
      final model = synced()..foldAll();

      expect(model.hiddenChars.single.start, 14); // after "void main() {\n"
      expect(model.hiddenChars.single.end, 28); // before "}"
    });

    test('toggle folds, then unfolds, and knows when there is nothing to fold', () {
      final model = synced();

      expect(model.toggle(0), isTrue);
      expect(model.isFolded(0), isTrue);
      expect(model.toggle(0), isFalse);
      expect(model.isFolded(0), isFalse);
      expect(model.toggle(2), isNull);
    });

    test('foldAll and unfoldAll say whether they did anything', () {
      final model = synced();

      expect(model.unfoldAll(), isFalse);
      expect(model.foldAll(), isTrue);
      expect(model.unfoldAll(), isTrue);
      expect(FoldModel().foldAll(), isFalse);
    });

    test('unfoldHiding opens the fold that hides a line', () {
      final model = synced()..foldAll();

      expect(model.unfoldHiding(0), isFalse); // the first line is shown
      expect(model.unfoldHiding(1), isTrue);
      expect(model.hasFolded, isFalse);
    });

    test('lineOfOffset', () {
      final model = synced();

      expect(model.lineOfOffset(0), 0);
      expect(model.lineOfOffset(14), 1);
      expect(model.lineOfOffset(20), 1);
      expect(model.lineOfOffset(28), 3);
    });

    test('an edit in the hidden lines unfolds on the next sync', () {
      final model = synced()..foldAll();
      final edited = block.replaceFirst('a();', 'aa();');

      model.remapForEdit(block, edited);
      model.sync(edited, () => const []);

      expect(model.hasFolded, isFalse);
    });

    test('an edit below keeps the fold', () {
      final model = synced()..foldAll();
      final edited = '${block}int y;\n';

      model.remapForEdit(block, edited);
      model.sync(edited, () => const []);

      expect(model.foldedStarts, [0]);
    });

    test('a fold whose region disappeared is dropped', () {
      final model = synced()..foldAll();

      model.sync('void main() {}\n', () => const []);

      expect(model.hasFolded, isFalse);
    });

    test('skip ranges are only asked for when the text changed', () {
      var asked = 0;
      final model = FoldModel();

      model.sync(block, () { asked++; return const []; });
      model.sync(block, () { asked++; return const []; });

      expect(asked, 1);
    });
  });
}
