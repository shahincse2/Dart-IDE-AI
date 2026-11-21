import 'package:dart_ide/widgets/project_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<ProjectAction>> pumpMenu(WidgetTester tester) async {
    final chosen = <ProjectAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ProjectMenu(onSelected: chosen.add)),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<ProjectAction>));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets('offers Rename and Delete', (tester) async {
    await pumpMenu(tester);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('choosing Rename reports it', (tester) async {
    final chosen = await pumpMenu(tester);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(chosen, [ProjectAction.rename]);
  });

  testWidgets('choosing Delete reports it', (tester) async {
    final chosen = await pumpMenu(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(chosen, [ProjectAction.delete]);
  });
}
