# AGENTS.md

Personal fork of `likhithpraveenk/sudoku`, used to add a staged solving-technique
coach and an AI-help export, and to ship it as a daily-driver Android build.

Start with `docs/handoff.md`: it explains the workflow, the current state and what to
pick up next. Anything that could reach the upstream author is governed by
`docs/upstream-contribution.md`; read it before touching git remotes, branches or PRs.

## Ground rules

- Never commit to `main`. The fork's `main` is a clean mirror of `upstream/main`
  and only moves by fast-forward (`git merge --ff-only upstream/main`). Personal
  work stays on `daily-driver` (or `multiplayer`, or a branch cut from them);
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
  from `daily-driver`, and never contains fork-only changes (applicationId,
  label, `fork-android.yml`, workflow edits, `AGENTS.md`, `docs/`, version bumps).
- **Big decisions need a second confirmation.** Before doing anything with real
  consequences (rewriting or deleting a branch, moving a feature to a new
  location, restructuring the repo, merging upstream into the fork, anything
  that touches the upstream author, or anything hard to undo), state the
  options with their trade-offs, say which one you recommend and why, and ask
  before acting. A quick "ok" is not informed consent: the owner is a designer,
  not a developer, and may not see a consequence that is obvious to an agent.
  Asking twice costs one message; unpicking a wrong call can cost a session.
- **UI follows Material 3, and the choice has to be argued.** Check the M3
  guidance for the component before proposing a placement or a layout, and say
  in one line why the choice is right. Rules learned the hard way:
  - An action that applies to the whole board belongs in the game top bar, with
    the other board-wide actions, labelled by tooltip. Do not bury it in an
    unrelated menu; hidden actions are not found.
  - Supporting text that applies to all of a sheet's or dialog's content sits
    directly under the headline, above that content. Helper text for a single
    control sits under that control.
  - Body and supporting text is `bodyMedium` (14) or larger; `bodySmall` (12)
    is Material's floor for captions, not for text people must read.
  - Icons are 48dp targets; sheets cap at 640dp; long labels wrap rather than
    truncate at large text sizes.
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

- `to-tickets` publishes one file per ticket in `docs/plans/`, one per vertical slice, named
`NNN-slug.md` (for example `001-run-locally.md`). Do not create GitHub issues
on the fork; its tracker is not used for this work. Upstream's tracker and
Discussions are a different matter, see the consent rule above.

Specs are written by `to-spec` into `docs/prd/`. This is the project's tracker
configuration for the global skills: local files, `docs/prd/` for the spec and
`docs/plans/` for the tickets, no triage labels, and no remote tracker. Ignore the
`to-spec`/`to-tickets` default of `.scratch/`; that is for projects with no
convention of their own.

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
  Skyscraper and Two-String Kite rather than by the upstream `TurbotFish`. The
  upstream class is sound (see `docs/upstream-contribution.md`, "Turbot Fish
  retracted"); the coach just does not delegate to it.
- The home screen shows a resume card for the most recent save, and the
  difficulty selector remembers the last played difficulty.
- X-Chains and XY-Chains are out of scope for now.
- Upstream contribution is no longer a non-goal, but it is opt-in per change.
  `daily-driver` stays the personal daily-driver; upstream gets only small,
  separately justified pieces (see `docs/upstream-contribution.md`). The PRD lines
  that list upstream contribution as out of scope describe the original fork
  intent and are superseded by this rule.
- Acceptance bar: correct step in every played game, Apply never leaves an
  invalid board, export lands a usable prompt in an AI chat, no noticeable
  pause, coach bar fits the phone without wrecking the grid, undo and resume
  still behave.
