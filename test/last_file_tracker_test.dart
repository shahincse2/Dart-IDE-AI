import 'package:dartlab/services/last_file_store.dart';
import 'package:dartlab/services/last_file_tracker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for FileProvider: something that changes and has a project and
/// an active file.
class Source extends ChangeNotifier {
  String? project;
  String? file;

  void change({String? project, String? file}) {
    this.project = project ?? this.project;
    this.file = file ?? this.file;
    notifyListeners();
  }
}

LastFileTracker trackerFor(Source source) => LastFileTracker(
      changes: source,
      projectId: () => source.project,
      activeFile: () => source.file,
    );

void main() {
  group('LastFileTracker', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves the active file of the project when it changes', () async {
      final source = Source();
      final tracker = trackerFor(source);

      source.change(project: 'loop', file: 'a.dart');
      await tracker.settled;

      expect(await LastFileStore().read('loop'), 'a.dart');
    });

    test('the newest file wins, and projects stay separate', () async {
      final source = Source();
      final tracker = trackerFor(source);

      source.change(project: 'one', file: 'a.dart');
      source.change(file: 'b.dart');
      source.change(project: 'two', file: 'x.dart');
      await tracker.settled;

      expect(await LastFileStore().read('one'), 'b.dart');
      expect(await LastFileStore().read('two'), 'x.dart');
    });

    test('nothing is saved without a project or an active file', () async {
      final source = Source();
      final tracker = trackerFor(source);

      source.change(project: 'loop'); // no file yet
      await tracker.settled;

      expect(await LastFileStore().read('loop'), isNull);
    });

    test('after dispose it no longer saves', () async {
      final source = Source();
      final tracker = trackerFor(source)..dispose();

      source.change(project: 'loop', file: 'a.dart');
      await tracker.settled;

      expect(await LastFileStore().read('loop'), isNull);
    });
  });
}
