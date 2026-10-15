import 'package:dartlab/widgets/editor_app_bar_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget titleWith({String? filePath, bool isDirty = false}) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: EditorAppBarTitle(
          fileName: 'main.dart',
          filePath: filePath,
          isDirty: isDirty,
        ),
      ),
    ),
  );
}

void main() {
  group('EditorAppBarTitle', () {
    testWidgets('shows the file name and, below it, the path', (tester) async {
      await tester.pumpWidget(titleWith(filePath: 'loop/src/main.dart'));

      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('loop/src/main.dart'), findsOneWidget);
    });

    testWidgets('without a path only the name is shown', (tester) async {
      await tester.pumpWidget(titleWith());

      expect(find.text('main.dart'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
