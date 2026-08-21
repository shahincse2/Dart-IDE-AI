# DartLab — Phase 3: Dart Runner

## What's new in this phase

```
lib/
├── models/console_event.dart          Output event model (stdout/stderr/exitCode)
├── services/dart_runner_service.dart  Isolate-based execution of tom_d4rt
└── providers/runner_provider.dart     Exposes run state to the widget tree
```

Run/Stop in the app bar are now live. A plain temporary output list
appears below the toolbar when there's something to show — it reads
the same `RunnerProvider.events` the real Console panel (Phase 4) will.

## Capability verification (done before writing runner code)

Checked `tom_d4rt`'s public API on pub.dev before building anything on
top of it:

- **No `cancel()`/`stop()`/`abort()` method exists on `D4rt`.** So the
  runner executes inside a dedicated `Isolate` — `Isolate.kill()` is
  the only genuine way to terminate a run in progress.
  `Future.timeout()` alone would only stop *waiting*, leaving the
  interpretation running in the background; Section 32/33 rules that
  out explicitly, so Stop and the 10s timeout are both real kills, not
  abandoned futures.
- `execute()` takes `positionalArgs`/`namedArgs` directly — real
  argument support exists. The runner already accepts an `args`
  parameter and threads it through, though the UI for entering
  arguments is Phase 8 (per the roadmap).
- No documented `cancel`/output-callback API beyond what's listed
  above — stdout is captured via Dart's own `Zone`-level `print`
  override (`ZoneSpecification(print: ...)`), a language mechanism
  independent of the package, so it doesn't depend on tom_d4rt
  exposing anything extra.
- Interactive `stdin` isn't attempted here — Section 55 puts it in
  Phase 8, and bridging a custom `stdin` implementation into the
  sandboxed interpreter needs real on-device testing to get right.

## What's real vs. still placeholder

**Real:**
- Executing typed Dart code and seeing actual output
- stdout/stderr distinguished in the temporary output list
- Stop button genuinely kills the running isolate
- 10-second timeout genuinely kills the isolate, not just gives up
  waiting

**Still placeholder:**
- The real Console panel — hidden by default, animated bottom sheet,
  drag-resize, copy/clear/save (Phase 4)
- Interactive stdin, argument-entry UI, error-location highlighting in
  the editor (Phase 8)
- Save (Phase 5), multi-file tabs (Phase 6)

## Known open issue carried over from Phase 2

The line-number gutter can still fall out of sync with the text after
certain edit sequences (reported with a screenshot: gutter stuck at
line 23 while the text had grown to 25 lines). The single-listener
refactor in the last update removed the most likely cause, but this
wasn't confirmed fixed before moving on to Phase 3. If you can
reproduce it again, a screen recording or the exact typing sequence
would help track down whatever's left.

## Before you run it

New dependency: `tom_d4rt: ^1.29.0` — run `flutter pub get`.
Unverified in this environment (no Flutter SDK / no pub.dev access
here); please confirm the version resolves cleanly on your machine.

Things worth checking on a real device:
1. A simple `print()` program actually shows output
2. A program with a runtime error shows it in the (red) stderr style
3. An infinite loop gets killed by the 10s timeout — the app should
   never freeze waiting on it
4. Tapping Stop mid-run actually stops it (try on a slow loop before
   it hits the timeout)

## Next up: Phase 4 — Console

Replace the temporary output list with the real hidden-by-default
animated bottom panel: drag-to-resize, copy/clear/save-as-.txt, and
opens automatically on Run or on an error.
