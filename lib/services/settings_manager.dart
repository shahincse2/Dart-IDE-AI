import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_model.dart';

/// Reads and writes [SettingsModel] to device-local key-value storage.
///
/// Kept separate from SettingsProvider so the persistence mechanism
/// (shared_preferences today) can change later without touching any
/// widget or provider code — providers only ever talk to services.
class SettingsManager {
  static const _keyThemeMode = 'dart_ide.themeMode';
  static const _keyFontSize = 'dart_ide.editorFontSize';
  static const _keyWordWrap = 'dart_ide.wordWrap';
  static const _keyIndentSize = 'dart_ide.indentSize';
  static const _keyAutoSave = 'dart_ide.autoSaveEnabled';
  static const _keyEditorTheme = 'dart_ide.editorThemeName';

  Future<SettingsModel> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsModel.fromPrefsMap({
      'themeMode': prefs.getString(_keyThemeMode),
      'editorFontSize': prefs.getDouble(_keyFontSize),
      'wordWrap': prefs.getBool(_keyWordWrap),
      'indentSize': prefs.getInt(_keyIndentSize),
      'autoSaveEnabled': prefs.getBool(_keyAutoSave),
      'editorThemeName': prefs.getString(_keyEditorTheme),
    });
  }

  Future<void> save(SettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, settings.themeMode.name);
    await prefs.setDouble(_keyFontSize, settings.editorFontSize);
    await prefs.setBool(_keyWordWrap, settings.wordWrap);
    await prefs.setInt(_keyIndentSize, settings.indentSize);
    await prefs.setBool(_keyAutoSave, settings.autoSaveEnabled);
    await prefs.setString(_keyEditorTheme, settings.editorThemeName);
  }
}
