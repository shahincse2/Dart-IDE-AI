import 'package:flutter/material.dart';

/// Immutable snapshot of user preferences.
///
/// Kept as a plain data class (not a ChangeNotifier itself) so it can
/// be freely copied, compared, and serialized. SettingsProvider owns
/// the mutable state and notifies listeners; this class is just the
/// shape of that state.
@immutable
class SettingsModel {
  final ThemeMode themeMode;
  final double editorFontSize;
  final bool wordWrap;
  final int indentSize;
  final bool autoSaveEnabled;
  final String editorThemeName; // e.g. 'Dark', 'Light' — extended in Phase 10

  const SettingsModel({
    this.themeMode = ThemeMode.system,
    this.editorFontSize = 14,
    this.wordWrap = false,
    this.indentSize = 2,
    this.autoSaveEnabled = true,
    this.editorThemeName = 'Dark',
  });

  SettingsModel copyWith({
    ThemeMode? themeMode,
    double? editorFontSize,
    bool? wordWrap,
    int? indentSize,
    bool? autoSaveEnabled,
    String? editorThemeName,
  }) {
    return SettingsModel(
      themeMode: themeMode ?? this.themeMode,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      wordWrap: wordWrap ?? this.wordWrap,
      indentSize: indentSize ?? this.indentSize,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      editorThemeName: editorThemeName ?? this.editorThemeName,
    );
  }

  // ---- Persistence helpers (shared_preferences stores primitives only) ----

  Map<String, Object> toPrefsMap() => {
        'themeMode': themeMode.name,
        'editorFontSize': editorFontSize,
        'wordWrap': wordWrap,
        'indentSize': indentSize,
        'autoSaveEnabled': autoSaveEnabled,
        'editorThemeName': editorThemeName,
      };

  factory SettingsModel.fromPrefsMap(Map<String, Object?> map) {
    return SettingsModel(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == (map['themeMode'] as String?),
        orElse: () => ThemeMode.system,
      ),
      editorFontSize: (map['editorFontSize'] as num?)?.toDouble() ?? 14,
      wordWrap: map['wordWrap'] as bool? ?? false,
      indentSize: map['indentSize'] as int? ?? 2,
      autoSaveEnabled: map['autoSaveEnabled'] as bool? ?? true,
      editorThemeName: map['editorThemeName'] as String? ?? 'Dark',
    );
  }
}
