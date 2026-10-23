import 'package:dartlab/providers/console_provider.dart';
import 'package:dartlab/providers/runner_provider.dart';
import 'package:dartlab/providers/settings_provider.dart';
import 'package:dartlab/widgets/console/console_stdin_bar.dart';
import 'package:dartlab/widgets/console_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A runner whose program is waiting for a line, so the input bar shows.
class _WaitingRunner extends RunnerProvider {
  @override
  bool get waitingForStdin => true;
}

Future<ConsoleProvider> pumpConsole(
  WidgetTester tester,
  RunnerProvider runner, {
  double? room,
}) async {
  final console = ConsoleProvider()..bind(runner);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
        ChangeNotifierProvider<RunnerProvider>.value(value: runner),
        ChangeNotifierProvider<ConsoleProvider>.value(value: console),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              ConsolePanel(roomHeight: room),
            ],
          ),
        ),
      ),
    ),
  );
  return console;
}

/// Plays the opening animation frame by frame: any frame that overflows
/// would be reported as an exception.
Future<void> openFrameByFrame(WidgetTester tester, ConsoleProvider console) async {
  console.open();
  for (var frame = 0; frame < 30; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('ConsolePanel never overflows', () {
    testWidgets('while it opens', (tester) async {
      final console = await pumpConsole(tester, RunnerProvider());

      await openFrameByFrame(tester, console);

      expect(tester.takeException(), isNull);
    });

    testWidgets('while it opens with the input bar showing', (tester) async {
      final console = await pumpConsole(tester, _WaitingRunner());

      await openFrameByFrame(tester, console);

      expect(find.byType(ConsoleStdinBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with little room left (keyboard up) and the input bar showing',
        (tester) async {
      final console = await pumpConsole(tester, _WaitingRunner(), room: 40);

      await openFrameByFrame(tester, console);

      expect(find.byType(ConsoleStdinBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
