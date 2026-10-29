import 'package:dartlab/utils/fold_regions.dart';
import 'package:dartlab/utils/fold_remap.dart';
import 'package:flutter_test/flutter_test.dart';

const block = 'int x;\nvoid main() {\n  a();\n  b();\n}\n'; // fold starts on line 1

Set<int> remap(String oldText, String newText, {Set<int> folded = const {1}}) {
  return remapFoldedStarts(
    oldText: oldText,
    newText: newText,
    regions: computeFoldRegions(oldText, const []),
    folded: folded,
    lineStarts: computeLineStarts(oldText),
  );
}

void main() {
  group('remapFoldedStarts', () {
    test('a line added above moves the fold down', () {
      expect(remap(block, 'import "a";\n$block'), {2});
    });

    test('a line removed above moves the fold up', () {
      const twoAbove = 'int x;\nint y;\nvoid main() {\n  a();\n  b();\n}\n';

      expect(
        remap(twoAbove, twoAbove.replaceFirst('int x;\n', ''), folded: const {2}),
        {1},
      );
    });

    test('typing on the line of the fold keeps it folded', () {
      expect(remap(block, block.replaceFirst('main', 'mainx')), {1});
    });

    test('typing in the lines above does not move it', () {
      expect(remap(block, block.replaceFirst('int x;', 'int xy;')), {1});
    });

    test('an edit below the fold leaves it alone', () {
      expect(remap(block, '${block}int y;\n'), {1});
    });

    test('an edit in the hidden lines unfolds it', () {
      expect(remap(block, block.replaceFirst('a();', 'aa();')), isEmpty);
    });

    test('a line break added on the line of the fold unfolds it', () {
      expect(remap(block, block.replaceFirst('void main()', 'void\nmain()')), isEmpty);
    });

    test('what was not folded stays not folded', () {
      expect(remap(block, 'import "a";\n$block', folded: const {}), isEmpty);
    });
  });
}
