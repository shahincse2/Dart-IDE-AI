import 'dart:async';

import 'package:tom_d4rt/tom_d4rt.dart';

/// Wraps `tom_d4rt`'s `eval()` for Phase 12's Variable Inspector.
///
/// The core capability (confirmed in docs):
///   - `D4rt.eval()` evaluates any expression in the same `Environment`
///     that the last `execute()` call left behind — so `var x = 10;`
///     declared in the user's script is accessible as `d4rt.eval('x')`.
///   - `D4rt.getEnvironmentState().variables` lists what's in scope.
///
/// The constraint: DartRunnerService's D4rt instance lives in a worker
/// Isolate and is killed when the run ends, so it can't be accessed
/// from the main isolate after the fact. Instead, EvalService keeps a
/// *separate* lightweight D4rt instance on the main isolate. When the
/// user's run finishes, setupSession() re-runs the same source here
/// (without touching stdout or the console — output is suppressed via
/// a Zone override). After that, eval() works normally.
///
/// What we DON'T claim:
///   - Step-through debugging (no breakpoint API exists in tom_d4rt)
///   - Inspecting local variables inside a function (the environment
///     at eval() time is the global/top-level scope; call frames from
///     main() are gone once execute() returns)
///   - Live watch / auto-refresh (this is query-on-demand only)
class EvalService {
  D4rt? _interpreter;
  bool _hasSession = false;
  bool _isSettingUp = false;

  bool get hasSession => _hasSession;
  bool get isSettingUp => _isSettingUp;

  /// Re-runs [source] on a fresh main-isolate D4rt instance so its
  /// post-execution environment is available for eval(). Output is
  /// silently suppressed — this is a background context-build, not a
  /// second visible execution. Call this after the worker isolate's run
  /// finishes successfully (i.e. exit code 0).
  Future<void> setupSession(String source, {List<String> args = const []}) async {
    _hasSession = false;
    _isSettingUp = true;
    final interpreter = D4rt();
    try {
      await runZoned(() async {
        await interpreter.execute(
          source: source,
          positionalArgs: args.isEmpty ? null : [args],
        );
      }, zoneSpecification: ZoneSpecification(
        // Suppress print() so re-running the script doesn't produce
        // duplicate console output.
        print: (self, parent, zone, line) {},
      ));
      _interpreter = interpreter;
      _hasSession = true;
    } catch (_) {
      // If re-execution fails (shouldn't happen — we only set up after
      // a confirmed successful run — but network/FS state might differ),
      // just leave the session unavailable rather than surfacing an
      // error for a background task the user didn't ask for.
      _hasSession = false;
    } finally {
      _isSettingUp = false;
    }
  }

  void clearSession() {
    _interpreter = null;
    _hasSession = false;
    _isSettingUp = false;
  }

  /// Evaluates [expression] in the post-run environment and returns a
  /// human-readable string of the result. Returns an error description
  /// (not a throw) on failure so the UI can display it inline.
  String eval(String expression) {
    final interpreter = _interpreter;
    if (interpreter == null || !_hasSession) {
      return '(no session — run your code first)';
    }
    try {
      final result = interpreter.eval(expression);
      if (result == null) return 'null';
      return result.toString();
    } catch (e) {
      return 'Error: ${_cleanError(e)}';
    }
  }

  /// Returns the names of top-level variables currently live in the
  /// global scope for the inspector's variable list.
  List<String> getEnvironmentVariableNames() {
    final interpreter = _interpreter;
    if (interpreter == null || !_hasSession) return const [];
    try {
      final state = interpreter.getEnvironmentState();
      final vars = state?.variables;
      if (vars == null) return const [];
      // getEnvironmentState().variables is List<EnvironmentVariableInfo>,
      // not List<String> — extract the name property from each entry.
      return vars.map((v) => v.name).toList();
    } catch (_) {
      return const [];
    }
  }

  String _cleanError(Object e) {
    final msg = e.toString();
    // Strip the "RuntimeD4rtException:" / "Exception:" prefix that
    // tom_d4rt adds so the user sees just the relevant part.
    return msg.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
  }
}