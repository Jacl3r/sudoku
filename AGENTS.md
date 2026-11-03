# AGENTS.md

Personal fork of `likhithpraveenk/sudoku`, used to add a staged solving-technique
coach and an AI-help export, and to ship it as a daily-driver Android build.

Start with `docs/handoff.md`: it explains the workflow, the current state and what to
pick up next.

## Ground rules

- Never commit or push to `main`. Work stays on `coach-and-export` or a branch
  cut from it.
- Do not create `v*` tags: `fork-android.yml` builds and publishes a signed
  release APK on any `v*` tag.
- Keep the UI clean and light. A change has to earn its weight, not just be
  correct.
- Respect layer boundaries: pure Sudoku logic in `lib/domain/`, persistence in
  `lib/data/`, Riverpod wiring in `lib/providers/`, widgets in
  `lib/presentation/`. `GameEngine` owns all in-game mutations.
- Tests sit beside the layer they cover (`test/domain`, `test/providers`).
  Widget tests are not used; layout and performance are checked manually on web
  and then on a device.
- Web is a functional harness only. Android is the acceptance target.

## Local toolchain

Flutter is installed outside the project at `/Users/jacler/flutter-3.47.0/flutter`,
the version `pubspec.yaml` pins (`flutter: 3.47.0`, Dart 3.13.0). Invoke it by
absolute path:

```sh
XDG_CONFIG_HOME=/Users/jacler/flutter-3.47.0/.config \
PUB_CACHE=/Users/jacler/flutter-3.47.0/.pub-cache \
/Users/jacler/flutter-3.47.0/flutter/bin/flutter <command>
```

Sandbox notes: `flutter test` and `flutter run` bind loopback sockets and must run
unsandboxed; `flutter analyze` needs a writable `~/.dartServer`; the Dart CLI needs
`~/.dart-tool`.

An unused Flutter 3.47.9 tree is also installed at `/Users/jacler/flutter`; delete
it whenever it becomes confusing.

## Issue tracking

- `to-issues` publishes plan files in `docs/plans/`, one per vertical slice, named
`NNN-slug.md` (for example `001-run-locally.md`). Do not create GitHub issues;
the fork's tracker is not used for this work.

PRDs live in `docs/prd/`. `coach-and-export.md` covers the coach, export and resume work
(slices 001–007). `home-and-settings.md` covers the home screen, import library and
settings redesign (slices 008–011) and is the active one.

## Product decisions

- The coach reasons on the full candidate set derived from placed digits. The
  player's notes are display-only: the coach must not infer candidates from
  them, and must never propose a placement that contradicts the puzzle solution.
- Applied coach eliminations are recorded on `GameState`, so they survive a
  restart, undo as one step, and show up in exports.
- Eliminations are only applied to cells that already have notes. The coach
  never invents notes on a cell the player has not written in.
- When the coach finds no step it offers an AI hand-off through the existing
  export sheet. The coach must cover every technique the app's own solver can
  apply, enforced by a coverage test. Turbot Fish is covered by the coach's own
  Skyscraper and Two-String Kite, not by the upstream `TurbotFish`, which can
  target a pattern cell.
- The home screen shows a resume card for the most recent save, and the
  difficulty selector remembers the last played difficulty.
- X-Chains and XY-Chains are out of scope for now.
- Acceptance bar: correct step in every played game, Apply never leaves an
  invalid board, export lands a usable prompt in an AI chat, no noticeable
  pause, coach bar fits the phone without wrecking the grid, undo and resume
  still behave.
