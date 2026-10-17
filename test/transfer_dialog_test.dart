import 'package:dartlab/models/project_file_node.dart';
import 'package:dartlab/models/project_model.dart';
import 'package:dartlab/models/tree_entry_ref.dart';
import 'package:dartlab/utils/transfer_destinations.dart';
import 'package:dartlab/widgets/file_tree/transfer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectModel project(String id) =>
    ProjectModel(id: id, name: id, rootPath: '/projects/$id');

ProjectFileNode folder(String path) => ProjectFileNode(
      name: path.split('/').last,
      type: FileNodeType.folder,
      relativePath: path,
    );

ProjectFileNode treeOf(List<String> folders) => ProjectFileNode(
      name: 'root',
      type: FileNodeType.folder,
      relativePath: '',
      children: [for (final path in folders) folder(path)],
    );

final trees = {
  'loop': treeOf(['lib', 'test']),
  'other': treeOf(['docs']),
};

class _Host extends StatefulWidget {
  const _Host({required this.projects});

  final List<ProjectModel> projects;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String answer = 'not answered';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final chosen = await showTransferDialog(
              context,
              title: 'Copy "main.dart" to',
              projects: widget.projects,
              current: widget.projects.first,
              loadTree: (p) async => trees[p.id]!,
              destinationsFor: (tree, p) => transferDestinations(
                tree,
                [const TreeEntryRef('main.dart', isFolder: false)],
                copy: true,
                sameProject: p.id == 'loop',
                rootLabel: p.name,
              ),
            );
            setState(() => answer =
                chosen == null ? 'null' : '${chosen.project.id}:${chosen.folder}');
          },
          child: const Text('open'),
        ),
        Text('answer: $answer'),
      ],
    );
  }
}

Future<void> openDialog(WidgetTester tester, List<ProjectModel> projects) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: _Host(projects: projects))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> switchTo(WidgetTester tester, String projectName) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(projectName).last);
  await tester.pumpAndSettle();
}

void main() {
  final both = [project('loop'), project('other')];

  group('showTransferDialog', () {
    testWidgets('starts with the folders of the current project', (tester) async {
      await openDialog(tester, both);

      expect(find.text('Copy "main.dart" to'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'loop'), findsOneWidget); // the root
      expect(find.widgetWithText(ListTile, 'lib'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'test'), findsOneWidget);
    });

    testWidgets('tapping a folder returns it with its project', (tester) async {
      await openDialog(tester, both);

      await tester.tap(find.widgetWithText(ListTile, 'lib'));
      await tester.pumpAndSettle();

      expect(find.text('answer: loop:lib'), findsOneWidget);
    });

    testWidgets('the project root can be chosen, and differs from cancelling', (tester) async {
      await openDialog(tester, both);

      await tester.tap(find.widgetWithText(ListTile, 'loop'));
      await tester.pumpAndSettle();

      expect(find.text('answer: loop:'), findsOneWidget);
    });

    testWidgets('switching project lists that project\'s folders', (tester) async {
      await openDialog(tester, both);

      await switchTo(tester, 'other');

      expect(find.widgetWithText(ListTile, 'docs'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'lib'), findsNothing);
    });

    testWidgets('a folder of another project is returned with that project', (tester) async {
      await openDialog(tester, both);
      await switchTo(tester, 'other');

      await tester.tap(find.widgetWithText(ListTile, 'docs'));
      await tester.pumpAndSettle();

      expect(find.text('answer: other:docs'), findsOneWidget);
    });

    testWidgets('with a single project there is nothing to switch', (tester) async {
      await openDialog(tester, [project('loop')]);

      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.widgetWithText(ListTile, 'lib'), findsOneWidget);
    });

    testWidgets('Cancel returns null', (tester) async {
      await openDialog(tester, both);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('answer: null'), findsOneWidget);
    });
  });
}
