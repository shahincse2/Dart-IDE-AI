import 'package:dartlab/utils/snippet_session.dart';
import 'package:dartlab/utils/text_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const session = SnippetSession(10, 30, [15, 25]);

  group('SnippetSession', () {
    test('contains the cursor from the start to the end of the snippet', () {
      expect(session.contains(10), isTrue);
      expect(session.contains(30), isTrue);
      expect(session.contains(9), isFalse);
      expect(session.contains(31), isFalse);
    });

    test('stopsAfter gives only the stops ahead of the cursor', () {
      expect(session.stopsAfter(12), [15, 25]);
      expect(session.stopsAfter(15), [25]);
      expect(session.stopsAfter(25), isEmpty);
    });

    test('an edit before the snippet moves all of it', () {
      const edit = TextEdit(5, 5, 7); // two letters typed at 5

      final moved = session.followEdit(edit)!;

      expect([moved.start, moved.end], [12, 32]);
      expect(moved.stops, [17, 27]);
    });

    test('an edit between two stops moves only the later ones', () {
      const edit = TextEdit(18, 18, 20); // two letters typed at 18

      final moved = session.followEdit(edit)!;

      expect(moved.stops, [15, 27]);
      expect(moved.end, 32);
    });

    test('an edit that replaces the last stop leaves nothing to go to', () {
      const edit = TextEdit(24, 26, 24); // 24..26 deleted

      expect(const SnippetSession(10, 30, [25]).followEdit(edit), isNull);
    });
  });
}
