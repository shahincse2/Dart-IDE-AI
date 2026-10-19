import 'package:dartlab/widgets/overlay_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget pageWith(List<String> messages) {
  var next = 0;
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        drawer: const Drawer(child: Text('drawer content')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => showOverlayMessage(
              Overlay.of(context, rootOverlay: true),
              messages[next++ % messages.length],
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('showOverlayMessage', () {
    testWidgets('shows the message, then removes it after a few seconds', (tester) async {
      await tester.pumpWidget(pageWith(['Moved 2 items']));

      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('Moved 2 items'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Moved 2 items'), findsNothing);
    });

    testWidgets('a new message replaces the one still showing', (tester) async {
      await tester.pumpWidget(pageWith(['first', 'second']));

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('it is still there while the drawer is open', (tester) async {
      await tester.pumpWidget(pageWith(['Copied 1 item']));
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));

      scaffold.openDrawer();
      await tester.pumpAndSettle();
      showOverlayMessage(
        Overlay.of(tester.element(find.text('drawer content')), rootOverlay: true),
        'Copied 1 item',
      );
      await tester.pump();

      expect(find.text('drawer content'), findsOneWidget);
      expect(find.text('Copied 1 item'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('it does not block taps on what is underneath', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ElevatedButton(
                onPressed: () {
                  taps++;
                  showOverlayMessage(
                    Overlay.of(context, rootOverlay: true),
                    'Saved',
                  );
                },
                child: const Text('tap me'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('tap me'));
      await tester.pump();
      await tester.tap(find.text('tap me'), warnIfMissed: false);
      await tester.pump();

      expect(taps, 2);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });
  });
}
