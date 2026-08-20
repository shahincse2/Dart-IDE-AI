import 'package:flutter/material.dart';

/// App-wide constants: spacing, sizing, durations, breakpoints.
///
/// Keeping these centralized means every screen/widget references the
/// same scale instead of inventing its own magic numbers (Section 3–4:
/// standard Android touch targets, consistent spacing).
class AppConstants {
  AppConstants._();

  // ---- App identity ----
  static const String appName = 'DartLab';

  // ---- Spacing scale (4pt grid) ----
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // ---- Touch targets ----
  /// Minimum recommended Android touch target (48dp), per Material
  /// Design accessibility guidance (Section 3, Section 46).
  static const double minTouchTarget = 48;

  /// Slightly smaller target acceptable for dense toolbars (coding
  /// toolbar chips) where many controls must fit on screen — still
  /// comfortably tappable at 40dp.
  static const double compactTouchTarget = 40;

  // ---- App bar / toolbar heights ----
  static const double appBarHeight = 56;
  static const double tabBarHeight = 40;
  static const double codingToolbarHeight = 48;

  // ---- Editor defaults ----
  static const double defaultFontSize = 14;
  static const double minFontSize = 10;
  static const double maxFontSize = 24;
  static const double editorLineHeight = 1.5;
  static const int defaultIndentSize = 2;

  // ---- Console ----
  static const double consoleMinHeight = 0;
  static const double consoleDefaultHeight = 260;
  static const double consoleDragHandleHeight = 20;

  // ---- Execution ----
  static const Duration executionTimeout = Duration(seconds: 10);

  // ---- Animation durations ----
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animBase = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);

  // ---- Autosave ----
  static const Duration autoSaveDebounce = Duration(milliseconds: 600);

  // ---- Responsive breakpoints ----
  /// Below this width: small phone (compact spacing).
  static const double breakpointSmallPhone = 360;

  /// Below this width: standard phone portrait layout (drawer nav).
  static const double breakpointPhone = 600;

  /// Below this width: large phone / small tablet.
  static const double breakpointTablet = 840;

  /// At or above this width: tablet layout (persistent sidebar).
  static const double breakpointTabletLarge = 1024;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= breakpointTablet;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;
}
