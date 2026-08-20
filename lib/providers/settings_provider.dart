import 'package:flutter/material.dart';

import '../models/settings_model.dart';
import '../services/settings_manager.dart';

/// Exposes user preferences to the widget tree and persists changes.
///
/// Widgets should read narrow slices via `context.select` where
/// possible (e.g. just `themeMode`) rather than the whole provider, so
/// an unrelated setting change doesn't rebuild the whole screen
/// (Section 51 — avoid unnecessary rebuilds).
class SettingsProvider extends ChangeNotifier {
  final SettingsManager _manager;

  SettingsModel _settings = const SettingsModel();
  bool _isLoaded = false;

  SettingsProvider({SettingsManager? manager})
      : _manager = manager ?? SettingsManager();

  SettingsModel get settings => _settings;
  bool get isLoaded => _isLoaded;

  ThemeMode get themeMode => _settings.themeMode;
  double get editorFontSize => _settings.editorFontSize;
  bool get wordWrap => _settings.wordWrap;
  int get indentSize => _settings.indentSize;
  bool get autoSaveEnabled => _settings.autoSaveEnabled;
  String get editorThemeName => _settings.editorThemeName;

  /// Loads persisted settings. Called once at app startup (see main.dart).
  Future<void> load() async {
    _settings = await _manager.load();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) => _update(
        _settings.copyWith(themeMode: mode),
      );

  Future<void> setEditorFontSize(double size) => _update(
        _settings.copyWith(
          editorFontSize: size.clamp(10, 24).toDouble(),
        ),
      );

  Future<void> setWordWrap(bool value) => _update(
        _settings.copyWith(wordWrap: value),
      );

  Future<void> setIndentSize(int size) => _update(
        _settings.copyWith(indentSize: size),
      );

  Future<void> setAutoSaveEnabled(bool value) => _update(
        _settings.copyWith(autoSaveEnabled: value),
      );

  Future<void> setEditorThemeName(String name) => _update(
        _settings.copyWith(editorThemeName: name),
      );

  Future<void> _update(SettingsModel next) async {
    _settings = next;
    notifyListeners();
    await _manager.save(next);
  }
}
