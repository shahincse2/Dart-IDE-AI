import 'package:flutter/material.dart';

import '../editor_color_scheme.dart';

const darkScheme = EditorColorScheme(
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

const lightScheme = EditorColorScheme(
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

const githubLightScheme = EditorColorScheme(
  name: 'GitHub Light',
  background: Color(0xFFFFFFFF),
  gutterBackground: Color(0xFFF6F8FA),
  gutterText: Color(0xFF8C959F),
  text: Color(0xFF1F2328),
  currentLine: Color(0xFFEAF5FB),
  selection: Color(0xFFBAE2FB),
  cursor: Color(0xFF0969DA),
  keyword: Color(0xFFCF222E),
  string: Color(0xFF0A3069),
  comment: Color(0xFF6E7781),
  number: Color(0xFF0550AE),
  annotation: Color(0xFF953800),
  function: Color(0xFF8250DF),
  type: Color(0xFF953800),
  variable: Color(0xFF1F2328),
  operatorColor: Color(0xFFCF222E),
  punctuation: Color(0xFF1F2328),
);
