import 'package:dartlab/widgets/name_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page with one button that opens the dialog and keeps its result.
class _Host extends StatefulWidget {
  const _Host({this.initialValue = '', this.hint});

  final String initialValue;
  final String? hint;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? result = 'not answered';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final name = await showNameDialog(
              context,
              title: 'New file',
              initialValue: widget.initialValue,
              hint: widget.hint,
            );
            setState(() => result = name);
          },
          child: const Text('open'),
        ),
        Text('result: $result'),
      ],
    );
  }
}

Future<void> openDialog(
  WidgetTester tester, {
  String initialValue = '',
  String? hint,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: _Host(initialValue: initialValue, hint: hint)),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showNameDialog', () {
    testWidgets('Enter on the keyboard confirms, like the button',
        (tester) async {
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), '  a.dart ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('result: a.dart'), findsOneWidget);
    });

    testWidgets('the OK button returns the trimmed text', (tester) async {
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), ' b.dart ');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('result: b.dart'), findsOneWidget);
    });

    testWidgets('Cancel returns null', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('starts with the initial value (rename)', (tester) async {
      await openDialog(tester, initialValue: 'old.dart');

      expect(find.text('old.dart'), findsOneWidget);
    });

    testWidgets('shows the hint while the field is empty', (tester) async {
      await openDialog(tester, hint: 'File name');

      expect(find.text('File name'), findsOneWidget);
    });

    testWidgets('the field has its underline even when no hint is given',
        (tester) async {
      await openDialog(tester);

      // No decoration at all would mean no underline (the bug this guards).
      expect(tester.widget<TextField>(find.byType(TextField)).decoration,
          isNotNull);
      expect(find.byType(InputDecorator), findsOneWidget);
    });
  });
}
