import 'package:dartlab/services/file_share_service.dart';
import 'package:dartlab/widgets/export_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeShare extends FileShareService {
  _FakeShare(this.outcome);

  final ExportOutcome outcome;

  @override
  Future<ExportOutcome> exportDartFile({
    required String content,
    required String fileName,
  }) async =>
      outcome;
}

Future<void> exportWith(WidgetTester tester, ExportOutcome outcome) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => exportWithMessage(
              context,
              content: 'void main() {}',
              fileName: 'main.dart',
              service: _FakeShare(outcome),
            ),
            child: const Text('export'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('export'));
  await tester.pump();
  await tester.pump();
}

Future<void> letMessageGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
}

void main() {
  group('exportWithMessage', () {
    testWidgets('says where the file was saved', (tester) async {
      await exportWith(tester, const ExportOutcome.saved('Download/DartLab/main.dart'));

      expect(find.text('Saved to Download/DartLab/main.dart'), findsOneWidget);
      await letMessageGo(tester);
    });

    testWidgets('says so when it could not be saved', (tester) async {
      await exportWith(tester, const ExportOutcome.failed());

      expect(find.text('Could not save "main.dart"'), findsOneWidget);
      await letMessageGo(tester);
    });

    testWidgets('says nothing when the user closed the save dialog', (tester) async {
      await exportWith(tester, const ExportOutcome.cancelled());

      expect(find.textContaining('Saved'), findsNothing);
      expect(find.textContaining('Could not'), findsNothing);
    });
  });
}
