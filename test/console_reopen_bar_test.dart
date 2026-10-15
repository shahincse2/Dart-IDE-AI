import 'package:dartlab/utils/themes.dart';
import 'package:dartlab/widgets/console/console_reopen_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget barWith({required bool isRunning, required VoidCallback onTap}) {
  return MaterialApp(
    home: Scaffold(
      body: ConsoleReopenBar(
        scheme: editorSchemeFromName('Dark'),
        isRunning: isRunning,
        onTap: onTap,
      ),
    ),
  );
}

void main() {
  group('ConsoleReopenBar', () {
    testWidgets('tapping the bar calls onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(barWith(isRunning: false, onTap: () => taps++));

      await tester.tap(find.text('Show console'));

      expect(taps, 1);
    });

    testWidgets('tells that a program is still running', (tester) async {
      await tester.pumpWidget(barWith(isRunning: true, onTap: () {}));

      expect(find.text('Console (running)'), findsOneWidget);
      expect(find.text('Show console'), findsNothing);
    });
  });
}
