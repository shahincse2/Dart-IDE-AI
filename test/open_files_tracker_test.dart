import 'package:dartlab/services/open_files_store.dart';
import 'package:dartlab/services/open_files_tracker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for FileProvider: something that changes, with a project, tabs
/// and an active file.
class Source extends ChangeNotifier {
  Object? project;
  List<String> tabs = [];
  String? active;

  void change({Object? project, List<String>? tabs, String? active}) {
    this.project = project ?? this.project;
    this.tabs = tabs ?? this.tabs;
    this.active = active ?? this.active;
    notifyListeners();
  }
}

OpenFilesTracker trackerFor(
  Source source, {
  Duration delay = const Duration(seconds: 5),
}) =>
    OpenFilesTracker(
      changes: source,
      projectId: () => source.project,
      openTabs: () => source.tabs,
      activeFile: () => source.active,
      delay: delay,
    );

void main() {
  group('OpenFilesTracker', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('flush saves the tabs and the active one right away', () async {
      final source = Source();
      final tracker = trackerFor(source);

      source.change(
          project: 'loop', tabs: ['a.dart', 'b.dart'], active: 'b.dart');
      await tracker.flush();

      final saved = await OpenFilesStore().read('loop');
      expect(saved!.tabs, ['a.dart', 'b.dart']);
      expect(saved.active, 'b.dart');
    });

    test('saves by itself once things have been quiet for a moment', () async {
      final source = Source();
      final tracker =
          trackerFor(source, delay: const Duration(milliseconds: 20));

      source.change(project: 'loop', tabs: ['a.dart'], active: 'a.dart');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tracker.settled;

      expect((await OpenFilesStore().read('loop'))!.tabs, ['a.dart']);
    });

    test('only the final state of a burst of changes is saved', () async {
      final source = Source();
      final tracker = trackerFor(source);

      source.change(project: 'loop', tabs: ['a.dart'], active: 'a.dart');
      source.change(tabs: ['a.dart', 'b.dart'], active: 'b.dart');
      await tracker.flush();

      expect((await OpenFilesStore().read('loop'))!.tabs, ['a.dart', 'b.dart']);
    });

    test(
        'closing the old project\'s tabs while switching does not overwrite it',
        () async {
      final source = Source();
      final tracker = trackerFor(source);

      source.change(project: 'A', tabs: ['x.dart', 'y.dart'], active: 'y.dart');
      await tracker.flush(); // A is saved

      // Opening project B: A's tabs close one by one, then B takes over.
      source.change(tabs: ['x.dart']);
      source.change(tabs: []);
      source.change(project: 'B');
      source.change(tabs: ['main.dart'], active: 'main.dart');
      await tracker.flush();

      expect((await OpenFilesStore().read('A'))!.tabs, ['x.dart', 'y.dart']);
      expect((await OpenFilesStore().read('B'))!.tabs, ['main.dart']);
    });

    test('nothing is saved without a project or without tabs', () async {
      final source = Source();
      final tracker = trackerFor(source);

      source.change(project: 'loop'); // no tabs yet
      await tracker.flush();

      expect(await OpenFilesStore().read('loop'), isNull);
    });

    test('after dispose it no longer saves', () async {
      final source = Source();
      final tracker =
          trackerFor(source, delay: const Duration(milliseconds: 10))
            ..dispose();

      source.change(project: 'loop', tabs: ['a.dart'], active: 'a.dart');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await tracker.settled;

      expect(await OpenFilesStore().read('loop'), isNull);
    });
  });
}
