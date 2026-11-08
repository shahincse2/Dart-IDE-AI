import 'package:flutter/material.dart';

import '../editor_color_scheme.dart';

const solarizedDarkScheme = EditorColorScheme(
  name: 'Solarized Dark',
  background: Color(0xFF002B36),
  gutterBackground: Color(0xFF073642),
  gutterText: Color(0xFF586E75),
  text: Color(0xFF839496),
  currentLine: Color(0xFF073642),
  selection: Color(0xFF073642),
  cursor: Color(0xFF839496),
  keyword: Color(0xFF859900),
  string: Color(0xFF2AA198),
  comment: Color(0xFF586E75),
  number: Color(0xFFD33682),
  annotation: Color(0xFFB58900),
  function: Color(0xFF268BD2),
  type: Color(0xFFB58900),
  variable: Color(0xFF839496),
  operatorColor: Color(0xFF859900),
  punctuation: Color(0xFF839496),
);

const nightOwlScheme = EditorColorScheme(
  name: 'Night Owl',
  background: Color(0xFF011627),
  gutterBackground: Color(0xFF011627),
  gutterText: Color(0xFF4B6479),
  text: Color(0xFFD6DEEB),
  currentLine: Color(0xFF0E2233),
  selection: Color(0xFF1D3B53),
  cursor: Color(0xFF80A4C2),
  keyword: Color(0xFFC792EA),
  string: Color(0xFFECC48D),
  comment: Color(0xFF637777),
  number: Color(0xFFF78C6C),
  annotation: Color(0xFFFFCB8B),
  function: Color(0xFF82AAFF),
  type: Color(0xFFFFCB8B),
  variable: Color(0xFFADDB67),
  operatorColor: Color(0xFF7FDBCA),
  punctuation: Color(0xFFD6DEEB),
);
