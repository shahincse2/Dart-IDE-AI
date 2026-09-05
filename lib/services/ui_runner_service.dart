import 'package:flutter/material.dart';
import 'package:tom_d4rt_flutter/tom_d4rt_flutter.dart';

/// Interprets Dart UI scripts into real, live Flutter widgets for
/// Section 37's "UI Run" mode, via `tom_d4rt_flutter`'s
/// `SourceFlutterD4rt` — the companion package to the `tom_d4rt`
/// interpreter already used for console execution (Phase 3).
///
/// Chosen instead of the master doc's originally-suggested
/// `flutter_d4rt` package specifically because that one turned out, on
/// checking, to be built on a *different*, unrelated interpreter
/// engine (`d4rt`, not `tom_d4rt`) and is an early "WIP" package with
/// very little adoption. Running two separate interpreter engines in
/// one app for no real benefit would be genuine architectural
/// inconsistency, not a neutral choice — `tom_d4rt_flutter` is
/// documented as "the primary, recommended way to run interpreted Dart
/// UI on Flutter" and shares everything (sandboxing model, bridge
/// surface, semantics) with the interpreter this app already uses.
///
/// Important constraint, stated plainly rather than hidden: this runs
/// on the main UI isolate. A `Widget` and a `BuildContext` can't cross
/// an Isolate boundary, so there's no way to give UI Run the same
/// genuine `Isolate.kill()`-based Stop/timeout that
/// [DartRunnerService] has for console execution. A script whose
/// `build()` function synchronously infinite-loops would freeze the UI
/// thread with nothing able to interrupt it from within the app. This
/// is a real limitation of rendering interpreted widgets in-process,
/// not something to paper over.
class UiRunnerService {
  final SourceFlutterD4rt _runner = SourceFlutterD4rt();
  bool _warmedUp = false;

  /// Moves the interpreter's one-time setup cost (parser front-end,
  /// stdlib registration) off of a script's first real build. Safe to
  /// call more than once — idempotent after the first call.
  void warmup() {
    if (_warmedUp) return;
    _warmedUp = true;
    _runner.warmup();
  }

  /// Interprets [source] — expected to declare a top-level
  /// `Widget build(BuildContext context)` function using real Flutter
  /// Material classes — and returns the live widget it produces.
  /// Throws (typically `SourceFlutterD4rtException`, but callers
  /// should catch broadly) on a syntax error, a runtime error, or
  /// source that isn't a UI script at all.
  Widget buildWidget(String source, BuildContext context) {
    return _runner.build<Widget>(source, context);
  }
}
