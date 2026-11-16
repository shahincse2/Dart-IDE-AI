import 'package:dartlab/widgets/keyboard_avoiding_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpSheet(WidgetTester tester, {required double keyboard}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.bottomCenter,
        child: KeyboardAvoidingSheet(
          child: SizedBox(key: const Key('content'), height: 100, width: 100),
        ),
      ),
    ),
  );
}

void main() {
  group('KeyboardAvoidingSheet', () {
    testWidgets('without a keyboard the content sits at the bottom', (tester) async {
      await pumpSheet(tester, keyboard: 0);

      expect(tester.getBottomLeft(find.byKey(const Key('content'))).dy, 800);
    });

    testWidgets('with the keyboard up the content stays above it', (tester) async {
      await pumpSheet(tester, keyboard: 300);

      expect(tester.getBottomLeft(find.byKey(const Key('content'))).dy, 500);
    });
  });
}
