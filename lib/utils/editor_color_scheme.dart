import 'package:flutter/material.dart';

import 'editor_schemes/classic_schemes.dart';
import 'editor_schemes/core_schemes.dart';
import 'editor_schemes/other_schemes.dart';

/// Color tokens for the code editor surface itself (background, text,
/// syntax colors, cursor, selection, current line, gutter).
///
/// This is deliberately separate from [AppTheme] (Material chrome)
/// because the editor's palette must stay legible for code regardless
/// of what accent color the rest of the app uses.
///
/// The palettes themselves are in `editor_schemes/`; the names below
/// (`EditorColorScheme.dark` and the others) are how the rest of the app
/// reaches them.
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

  static const dark = darkScheme;
  static const light = lightScheme;
  static const dracula = draculaScheme;
  static const monokai = monokaiScheme;
  static const solarizedDark = solarizedDarkScheme;
  static const oneDark = oneDarkScheme;
  static const nightOwl = nightOwlScheme;
  static const githubLight = githubLightScheme;

  /// All themes, in the order they should be offered in Settings.
  static const List<EditorColorScheme> all = [
    dark,
    light,
    dracula,
    monokai,
    oneDark,
    solarizedDark,
    nightOwl,
    githubLight,
  ];
}
