import 'package:flutter/material.dart';

/// Color tokens for the code editor surface itself (background, text,
/// syntax colors, cursor, selection, current line, gutter).
///
/// This is deliberately separate from [AppTheme] (Material chrome)
/// because the editor's palette must stay legible for code regardless
/// of what accent color the rest of the app uses.
@immutable
class EditorColorScheme {
  final String name;
  final Color background;
  final Color gutterBackground;
  final Color gutterText;
  final Color text;
  final Color currentLine;
  final Color selection;
  final Color cursor;

  // Syntax token colors
  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color annotation;
  final Color function;
  final Color type;
  final Color variable;
  final Color operatorColor;
  final Color punctuation;

  const EditorColorScheme({
    required this.name,
    required this.background,
    required this.gutterBackground,
    required this.gutterText,
    required this.text,
    required this.currentLine,
    required this.selection,
    required this.cursor,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.annotation,
    required this.function,
    required this.type,
    required this.variable,
    required this.operatorColor,
    required this.punctuation,
  });

  static const dark = EditorColorScheme(
    name: 'Dark',
    background: Color(0xFF1E1E1E),
    gutterBackground: Color(0xFF1E1E1E),
    gutterText: Color(0xFF858585),
    text: Color(0xFFD4D4D4),
    currentLine: Color(0xFF2A2D2E),
    selection: Color(0xFF264F78),
    cursor: Color(0xFFAEAFAD),

    // Syntax colors
    keyword: Color(0xFFC586C0),
    string: Color(0xFFCE9178),
    comment: Color(0xFF6A9955),
    number: Color(0xFFB5CEA8),
    annotation: Color(0xFFDCDCAA),
    function: Color(0xFFDCDCAA),
    type: Color(0xFF4EC9B0),
    variable: Color(0xFF9CDCFE),
    operatorColor: Color(0xFFD4D4D4),
    punctuation: Color(0xFFD4D4D4),
  );

  static const light = EditorColorScheme(
    name: 'Light',
    background: Color(0xFFFFFFFF),
    gutterBackground: Color(0xFFFFFFFF),
    gutterText: Color(0xFFA0A0A0),
    text: Color(0xFF2C2C2A),
    currentLine: Color(0xFFF1F1F1),
    selection: Color(0xFFCEDEFB),
    cursor: Color(0xFF185FA5),

    // Syntax colors
    keyword: Color(0xFF534AB7),
    string: Color(0xFF0F6E56),
    comment: Color(0xFF8A8A85),
    number: Color(0xFF993C1D),
    annotation: Color(0xFF854F0B),
    function: Color(0xFF185FA5),
    type: Color(0xFF854F0B),
    variable: Color(0xFF2C2C2A),
    operatorColor: Color(0xFF993C1D),
    punctuation: Color(0xFF6B6B67),
  );

  /// Phase 10: the two classic editor themes Section 42 names
  /// explicitly, using their well-known real palettes.
  static const dracula = EditorColorScheme(
    name: 'Dracula',
    background: Color(0xFF282A36),
    gutterBackground: Color(0xFF282A36),
    gutterText: Color(0xFF6272A4),
    text: Color(0xFFF8F8F2),
    currentLine: Color(0xFF44475A),
    selection: Color(0xFF44475A),
    cursor: Color(0xFFF8F8F0),

    // Syntax colors
    keyword: Color(0xFFFF79C6),
    string: Color(0xFFF1FA8C),
    comment: Color(0xFF6272A4),
    number: Color(0xFFBD93F9),
    annotation: Color(0xFFFFB86C),
    function: Color(0xFF50FA7B),
    type: Color(0xFF8BE9FD),
    variable: Color(0xFFF8F8F2),
    operatorColor: Color(0xFFFF79C6),
    punctuation: Color(0xFFF8F8F2),
  );

  static const monokai = EditorColorScheme(
    name: 'Monokai',
    background: Color(0xFF272822),
    gutterBackground: Color(0xFF272822),
    gutterText: Color(0xFF75715E),
    text: Color(0xFFF8F8F2),
    currentLine: Color(0xFF3E3D32),
    selection: Color(0xFF49483E),
    cursor: Color(0xFFF8F8F0),

    // Syntax colors
    keyword: Color(0xFFF92672),
    string: Color(0xFFE6DB74),
    comment: Color(0xFF75715E),
    number: Color(0xFFAE81FF),
    annotation: Color(0xFF66D9EF),
    function: Color(0xFFA6E22E),
    type: Color(0xFF66D9EF),
    variable: Color(0xFFF8F8F2),
    operatorColor: Color(0xFFF92672),
    punctuation: Color(0xFFF8F8F2),
  );

  /// All themes, in the order they should be offered in Settings.
  static const List<EditorColorScheme> all = [
    dark,
    light,
    dracula,
    monokai,
  ];
}

/// App-level Material theming (chrome: app bar, buttons, drawer, etc).
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF378ADD);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      // No custom fonts bundled yet (see pubspec.yaml note) — Material 3
      // default type scale is used until an offline font asset is added.
    );
  }
}

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

//=======================================================================================================================================================
// import 'package:flutter/material.dart';
//
// /// Color tokens for the code editor surface itself (background, text,
// /// syntax colors, cursor, selection, current line, gutter).
// ///
// /// This is deliberately separate from [AppTheme] (Material chrome)
// /// because the editor's palette must stay legible for code regardless
// /// of what accent color the rest of the app uses.
// @immutable
// class EditorColorScheme {
//   final String name;
//   final Color background;
//   final Color gutterBackground;
//   final Color gutterText;
//   final Color text;
//   final Color currentLine;
//   final Color selection;
//   final Color cursor;
//
//   // Syntax token colors
//   final Color keyword;
//   final Color string;
//   final Color comment;
//   final Color number;
//   final Color function;
//   final Color type;
//   final Color variable;
//   final Color operatorColor;
//
//   const EditorColorScheme({
//     required this.name,
//     required this.background,
//     required this.gutterBackground,
//     required this.gutterText,
//     required this.text,
//     required this.currentLine,
//     required this.selection,
//     required this.cursor,
//     required this.keyword,
//     required this.string,
//     required this.comment,
//     required this.number,
//     required this.function,
//     required this.type,
//     required this.variable,
//     required this.operatorColor,
//   });
//
//   static const dark = EditorColorScheme(
//     name: 'Dark',
//     background: Color(0xFF1E1E1E),
//     gutterBackground: Color(0xFF1E1E1E),
//     gutterText: Color(0xFF5A5A5A),
//     text: Color(0xFFD4D4D4),
//     currentLine: Color(0xFF2A2A2A),
//     selection: Color(0xFF264F78),
//     cursor: Color(0xFF528BFF),
//     keyword: Color(0xFF7F77DD),
//     string: Color(0xFF6FCF97),
//     comment: Color(0xFF6A6A6A),
//     number: Color(0xFFE0A85E),
//     function: Color(0xFF61AFEF),
//     type: Color(0xFFE5C07B),
//     variable: Color(0xFFD4D4D4),
//     operatorColor: Color(0xFFD19A66),
//   );
//
//   static const light = EditorColorScheme(
//     name: 'Light',
//     background: Color(0xFFFFFFFF),
//     gutterBackground: Color(0xFFFFFFFF),
//     gutterText: Color(0xFFA0A0A0),
//     text: Color(0xFF2C2C2A),
//     currentLine: Color(0xFFF1F1F1),
//     selection: Color(0xFFCEDEFB),
//     cursor: Color(0xFF185FA5),
//     keyword: Color(0xFF534AB7),
//     string: Color(0xFF0F6E56),
//     comment: Color(0xFF8A8A85),
//     number: Color(0xFF993C1D),
//     function: Color(0xFF185FA5),
//     type: Color(0xFF854F0B),
//     variable: Color(0xFF2C2C2A),
//     operatorColor: Color(0xFF993C1D),
//   );
//
//   /// Phase 10: the two classic editor themes Section 42 names
//   /// explicitly, using their well-known real palettes.
//   static const dracula = EditorColorScheme(
//     name: 'Dracula',
//     background: Color(0xFF282A36),
//     gutterBackground: Color(0xFF282A36),
//     gutterText: Color(0xFF6272A4),
//     text: Color(0xFFF8F8F2),
//     currentLine: Color(0xFF44475A),
//     selection: Color(0xFF44475A),
//     cursor: Color(0xFFF8F8F0),
//     keyword: Color(0xFFFF79C6),
//     string: Color(0xFFF1FA8C),
//     comment: Color(0xFF6272A4),
//     number: Color(0xFFBD93F9),
//     function: Color(0xFF50FA7B),
//     type: Color(0xFF8BE9FD),
//     variable: Color(0xFFF8F8F2),
//     operatorColor: Color(0xFFFF79C6),
//   );
//
//   static const monokai = EditorColorScheme(
//     name: 'Monokai',
//     background: Color(0xFF272822),
//     gutterBackground: Color(0xFF272822),
//     gutterText: Color(0xFF75715E),
//     text: Color(0xFFF8F8F2),
//     currentLine: Color(0xFF3E3D32),
//     selection: Color(0xFF49483E),
//     cursor: Color(0xFFF8F8F0),
//     keyword: Color(0xFFF92672),
//     string: Color(0xFFE6DB74),
//     comment: Color(0xFF75715E),
//     number: Color(0xFFAE81FF),
//     function: Color(0xFFA6E22E),
//     type: Color(0xFF66D9EF),
//     variable: Color(0xFFF8F8F2),
//     operatorColor: Color(0xFFF92672),
//   );
//
//   /// All themes, in the order they should be offered in Settings.
//   static const List<EditorColorScheme> all = [dark, light, dracula, monokai];
// }
//
// /// App-level Material theming (chrome: app bar, buttons, drawer, etc).
// class AppTheme {
//   AppTheme._();
//
//   static const _seed = Color(0xFF378ADD);
//
//   static ThemeData light() {
//     final scheme = ColorScheme.fromSeed(
//       seedColor: _seed,
//       brightness: Brightness.light,
//     );
//     return _base(scheme);
//   }
//
//   static ThemeData dark() {
//     final scheme = ColorScheme.fromSeed(
//       seedColor: _seed,
//       brightness: Brightness.dark,
//     );
//     return _base(scheme);
//   }
//
//   static ThemeData _base(ColorScheme scheme) {
//     return ThemeData(
//       useMaterial3: true,
//       colorScheme: scheme,
//       scaffoldBackgroundColor: scheme.surface,
//       appBarTheme: AppBarTheme(
//         backgroundColor: scheme.surface,
//         foregroundColor: scheme.onSurface,
//         elevation: 0,
//         scrolledUnderElevation: 0.5,
//         centerTitle: false,
//       ),
//       dividerTheme: DividerThemeData(
//         color: scheme.outlineVariant,
//         thickness: 0.5,
//         space: 0.5,
//       ),
//       visualDensity: VisualDensity.standard,
//       splashFactory: InkSparkle.splashFactory,
//       // No custom fonts bundled yet (see pubspec.yaml note) — Material 3
//       // default type scale is used until an offline font asset is added.
//     );
//   }
// }
//
// /// The editor's monospace font family. Falls back to the platform's
// /// built-in monospace face since no font asset is bundled yet
// /// (see pubspec.yaml). Swapping in a custom offline font later only
// /// requires changing this one constant.
// const String editorFontFamily = 'monospace';
//
// /// Resolves a persisted theme name (from [SettingsModel.editorThemeName])
// /// to its [EditorColorScheme]. Falls back to Dark for anything
// /// unrecognized (e.g. corrupted preferences).
// EditorColorScheme editorSchemeFromName(String name) {
//   for (final scheme in EditorColorScheme.all) {
//     if (scheme.name == name) return scheme;
//   }
//   return EditorColorScheme.dark;
// }
