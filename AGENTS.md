# AGENTS.md

Personal fork of `likhithpraveenk/sudoku`, used to add a staged solving-technique
coach and an AI-help export, and to ship it as a daily-driver Android build.

Start with `docs/handoff.md`: it explains the workflow, the current state and what to
pick up next. Anything that could reach the upstream author is governed by
`docs/upstream-contribution.md`; read it before touching git remotes, branches or PRs.

## Ground rules

- Never commit to `main`. The fork's `main` is a clean mirror of `upstream/main`
  and only moves by fast-forward (`git merge --ff-only upstream/main`). Personal
  work stays on `coach-and-export` (or `multiplayer`, or a branch cut from them);
  upstream-bound work goes on its own branch cut from `upstream/main`.
- Never push tags to `origin`. Upstream's tags (`v1.2.0` ...) would trigger a
  release build in the fork.
- Do not create `v*` tags: `fork-android.yml` builds and publishes a signed
  release APK on any `v*` tag.
- Upstream contact needs the owner's explicit consent, every time. That means
  opening a pull request, a Discussion or an issue, or commenting on anything in
  `likhithpraveenk/sudoku`. Pushing a branch to `origin` (the fork) is allowed, but
  it does not count as consent to contact upstream. Ask first, say what the
  consequences are for the upstream author, and wait for a clear yes. A past
  yes does not carry over to the next time.
- Work meant for upstream is cut as a small branch from `upstream/main`, never
  from `coach-and-export`, and never contains fork-only changes (applicationId,
  label, `fork-android.yml`, workflow edits, `AGENTS.md`, `docs/`, version bumps).
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
`NNN-slug.md` (for example `001-run-locally.md`). Do not create GitHub issues
on the fork; its tracker is not used for this work. Upstream's tracker and
Discussions are a different matter, see the consent rule above.

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
- Upstream contribution is no longer a non-goal, but it is opt-in per change.
  `coach-and-export` stays the personal daily-driver; upstream gets only small,
  separately justified pieces (see `docs/upstream-contribution.md`). The PRD lines
  that list upstream contribution as out of scope describe the original fork
  intent and are superseded by this rule.
- Acceptance bar: correct step in every played game, Apply never leaves an
  invalid board, export lands a usable prompt in an AI chat, no noticeable
  pause, coach bar fits the phone without wrecking the grid, undo and resume
  still behave.
