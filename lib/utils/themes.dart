import 'editor_color_scheme.dart';

// One import for everything about themes. The pieces: the editor palettes
// (editor_color_scheme.dart, editor_schemes/) and the Material chrome
// (app_theme.dart).
export 'app_theme.dart';
export 'editor_color_scheme.dart';

/// The editor's monospace font family. Falls back to the platform's
/// built-in monospace face since no font asset is bundled yet
/// (see pubspec.yaml). Swapping in a custom offline font later only
/// requires changing this one constant.
const String editorFontFamily = 'monospace';

/// Resolves a persisted theme name (from [SettingsModel.editorThemeName])
/// to its [EditorColorScheme]. Falls back to Dark for anything
/// unrecognized (e.g. corrupted preferences).
EditorColorScheme editorSchemeFromName(String name) {
  for (final scheme in EditorColorScheme.all) {
    if (scheme.name == name) return scheme;
  }
  return EditorColorScheme.dark;
}
