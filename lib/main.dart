import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        // FileProvider, ProjectProvider, ConsoleProvider, RunnerProvider,
        // and EditorProvider are added in their respective phases
        // (5, 5, 4, 3, 2) rather than stubbed here — an empty provider
        // with nothing to manage is unused architecture (Rule 59).
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
