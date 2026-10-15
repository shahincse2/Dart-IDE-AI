import 'package:dartlab/utils/themes.dart';
import 'package:dartlab/widgets/code_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeEditorController.scheme', () {
    test('listeners are told after the change, not during it', () async {
      final controller = CodeEditorController(scheme: EditorColorScheme.dark);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.scheme = EditorColorScheme.light;

      expect(controller.scheme, EditorColorScheme.light);
      expect(notified, 0); // nothing yet: this may be happening inside build()

      await Future<void>.delayed(Duration.zero);
      expect(notified, 1);
      controller.dispose();
    });

    test('setting the same scheme notifies nobody', () async {
      final controller = CodeEditorController(scheme: EditorColorScheme.dark);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.scheme = EditorColorScheme.dark;
      await Future<void>.delayed(Duration.zero);

      expect(notified, 0);
      controller.dispose();
    });

    test('a controller disposed right after the change is left alone', () async {
      final controller = CodeEditorController(scheme: EditorColorScheme.dark);

      controller.scheme = EditorColorScheme.light;
      controller.dispose();

      // The pending notification must not throw on the disposed controller.
      await Future<void>.delayed(Duration.zero);
    });
  });
}
