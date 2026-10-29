import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/themes.dart';

/// Height of one visual row.
double editorLineHeight(double fontSize) =>
    fontSize * AppConstants.editorLineHeight;

/// Forced strut: every visual row is exactly one line tall.
StrutStyle editorStrutStyle(double fontSize) => StrutStyle(
      fontFamily: editorFontFamily,
      fontSize: fontSize,
      height: AppConstants.editorLineHeight,
      forceStrutHeight: true,
    );

/// The exact style the TextField renders with. TextField merges the Material
/// text theme (bodyLarge in M3, which carries a letterSpacing) under the style
/// we pass, so we do the same merge here and pass the result to the TextField
/// — measuring and rendering then agree.
TextStyle editorTextStyle(
  BuildContext context,
  EditorColorScheme scheme,
  double fontSize,
) {
  final theme = Theme.of(context);
  final base = (theme.useMaterial3
          ? theme.textTheme.bodyLarge
          : theme.textTheme.titleMedium) ??
      const TextStyle();
  return base.merge(
    TextStyle(
      fontFamily: editorFontFamily,
      fontSize: fontSize,
      height: AppConstants.editorLineHeight,
      color: scheme.text,
    ),
  );
}
