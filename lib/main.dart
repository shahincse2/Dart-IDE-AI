import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/console_provider.dart';
import 'providers/file_provider.dart';
import 'providers/runner_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';
import 'utils/themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DartLabApp());
}

/// Root widget. Loads persisted settings once, then hands theme mode
/// down through SettingsProvider so any screen can react to changes
/// (e.g. Settings screen in Phase 10) without rebuilding this widget.
class DartLabApp extends StatelessWidget {
  const DartLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => RunnerProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FileProvider(),
        ),
        // ConsoleProvider only manages visibility/sizing — it reads
        // RunnerProvider's events rather than duplicating them, so it
        // needs a reference to it. ChangeNotifierProxyProvider is the
        // standard `provider` pattern for "this provider depends on
        // that one".
        ChangeNotifierProxyProvider<RunnerProvider, ConsoleProvider>(
          create: (_) => ConsoleProvider(),
          update: (_, runner, console) => (console ?? ConsoleProvider())..bind(runner),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
