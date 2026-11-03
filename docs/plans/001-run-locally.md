# 001 — Run the branch locally

Parent: `docs/prd/coach-and-export.md`, slice 1
Depends on: none
Blocks: 002, 003, 004, 005, 006

## Why

The coach and export work on `coach-and-export` has never run on this machine.
There is no Flutter SDK installed, so the only signal so far is CI. Nothing else
can be judged — correctness, latency or layout — until the app boots.

## Scope

- Install a Flutter SDK whose bundled Dart satisfies `sdk: ^3.12.1` and supports
  the dot-shorthand syntax already used throughout `lib/` (`: .easy`,
  `.circular(6)`, `?coachBar`).
- `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`.
- `flutter run -d chrome` and walk the baseline checklist: new game on Hard and
  Expert, coach stages and Apply, export content × format, Copy, Link/Open.
- Record what CI says about the branch, specifically whether the `check` job in
  `.github/workflows/fork-android.yml` passes.
- Write findings down; change nothing.

## Out of scope

- Fixing anything found (that is slices 002–006).
- Installing the Android SDK or a device toolchain.
- Changing CI.

## Acceptance criteria

- [ ] `flutter analyze` and `flutter test` pass, or every failure is recorded as a
      pre-existing failure with the test name.
- [ ] The app boots in Chrome at a phone-sized viewport.
- [ ] Both branch features are reachable: `Hint → Next step` opens the coach bar;
      the share icon opens the export sheet.
- [ ] Each finding is written into the relevant slice file or the PRD risks
      section, phrased as an observation rather than a fix.

## Testing

Manual. This slice exists to enable automated testing, not to add any.

## Notes

- Network access is required for the SDK download and `pub get`.
- `pubspec.yaml` pins `flutter: 3.47.0` exactly, and `fork-android.yml` reads that
  pin through `flutter-version-file`. Install 3.47.0 rather than the newest stable,
  or version solving fails.
- Version pinning matters here: the codebase already requires a very recent Dart
  (dot shorthands, null-aware elements), so do not install an older channel to get
  moving.

## Findings (2026-11-03)

- Installed Flutter 3.47.0 / Dart 3.13.0 at `/Users/jacler/flutter-3.47.0`; the
  command line and sandbox workarounds are recorded in `AGENTS.md`.
- `flutter pub get --enforce-lockfile`: resolves cleanly against the lockfile.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: passes. Two infos, both in
  new coach code: `prefer_if_elements_to_conditional_expressions` in
  `lib/domain/coach/coach.dart` and `unnecessary_lambdas` in
  `test/domain/coach/coach_test.dart`.
- `flutter test`: 125 tests pass, including the generated-puzzle coach walk.
- `flutter build web --release`: succeeds.
- `flutter run -d chrome`: boots, opens all four Hive boxes, no launch errors.
- Still unverified: the manual checklist (coach stages, Apply, export matrix, small
  viewport), which needs a human in the browser, and the CI `check` job.
