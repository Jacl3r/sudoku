# Handoff — session diary

Read this first in a new session. It explains what the project is, how we work, where the
state lives, and what to pick up next.

Last updated: 2026-11-04

## What this project is

A personal fork of `likhithpraveenk/sudoku` (Flutter), used as a daily driver and a place to
tinker. Two features were added on top of upstream: a staged solving-technique **coach**, and
an **export** sheet that turns a stuck board into a prompt for an AI. The fork installs next
to the F-Droid build (`com.jacl3r.sudoku`, label "Sudoku+").

Ground rules (also in `AGENTS.md`): work stays on `coach-and-export`, never `main`; never
create `v*` tags, because `fork-android.yml` publishes a signed release on them; keep the UI
clean and light.

## How we work

Four steps, each producing a file:

1. **ideation** — an interview until every decision is made. No file.
2. **to-prd** — one PRD in `docs/prd/`, grounded in the code.
3. **to-issues** — one plan file per vertical slice in `docs/plans/NNN-slug.md`, with parent,
   dependencies, scope, acceptance criteria, testing seam and notes.
4. **implement** one slice, tick its acceptance criteria, and append a Findings section
   describing what changed and what was discovered.

The three skills live in `~/.agents/skills/` and are invoked explicitly.

Verification loop for every slice:

```sh
XDG_CONFIG_HOME=/Users/jacler/flutter-3.47.0/.config \
PUB_CACHE=/Users/jacler/flutter-3.47.0/.pub-cache \
/Users/jacler/flutter-3.47.0/flutter/bin/flutter analyze --no-fatal-infos --no-fatal-warnings
# then `flutter test`, and `flutter build web --release` when UI changed
```

Tests live beside the layer (`test/domain`, `test/providers`, `test/data`). There are no
widget tests by choice; layout and feel are checked manually on web at 390×844 and 360×640,
then on the phone.

## Environment

- Flutter **3.47.0** / Dart 3.13.0 at `/Users/jacler/flutter-3.47.0/flutter`. The pin in
  `pubspec.yaml` is exact; 3.47.9 fails version solving.
- Always pass `XDG_CONFIG_HOME` and `PUB_CACHE` as above, or the toolchain writes outside the
  directory it owns.
- Sandbox notes: `flutter test` and `flutter run` bind loopback sockets and must run
  unsandboxed; `flutter analyze` needs a writable `~/.dartServer`; the Dart CLI needs
  `~/.dart-tool`. Those directories exist now.
- Web state is IndexedDB. To get a first-run experience again: DevTools → Application →
  Storage → Clear site data.
- No Android SDK is installed yet, so nothing has run on a phone.

## Where things stand

Two PRDs, eleven slices, all implemented:

| Slice | What it delivered |
|---|---|
| 001 | Local toolchain, analyze/test/build green |
| 002 | Coach reasons on full candidates minus a recorded elimination ledger; sound, no repeats, notes untouched |
| 003 | Coach coverage guaranteed by a test; Turbot covered by Skyscraper/Kite |
| 004 | Export last mile: share fallback, wording, link/prompt matrix, after completion |
| 005 | Coach latency measured, bar scales with text, grid no longer overflows, dead end hands off to AI |
| 006 | Resume entry + remembered difficulty |
| 007 | Screening: five fixes (stale import, Turbot pattern cells, Appearance swatches, delete confirm, copy) |
| 008 | Import library with its own storage and keys |
| 009 | Settings in four sections with previews next to their controls |
| 010 | Home IA: five-page carousel, pips, Continue emphasised, top bar reduced |
| 011 | One-time theme sheet on first launch |
| 012 | Same-digit highlight at full weight; keyboard shortcuts with desktop tooltip hints |
| 013 | Undo survives a save: every action type is serialized with the state |

Current numbers: **159 tests**, `flutter analyze` clean, web build green.

Slices 001–011 are committed and pushed to `origin/coach-and-export` as **`564663b`** (53
files, +4090/−317); slice 012 landed in a follow-up commit on the same branch. The fork's
`main` is untouched at `403bbfc`. One commit per session on purpose: the slice docs carry the
history, and the tree was tested as a whole.

## Pick up here next session

1. **Android toolchain (highest value).** Install the SDK/JDK, run `flutter doctor`, then
   `flutter build apk --debug` and install over USB. That unlocks the only acceptance checks
   that are still unmeasured:
   - `nextCoachStep` latency on the device (desktop VM was p95 0.8 ms, max 3.4 ms);
   - the coach bar at 360×640 and at 2× text (grid lands near 168 px — tight);
   - the Android share sheet;
   - the first-run theme sheet on a real install.
2. **Slice 014** is written and waiting: delete the dead `PuzzleImportService.sharePuzzle`, its
   test, and the imports only it needed.
3. **Manual web pass** if the device is not ready: settings sections and previews; the
   five-page carousel, pips and action swapping; the first-run sheet after clearing site
   data; and slice 012 — select a digit and compare the matches, open the coach to a pattern
   to confirm its tint survives, walk every shortcut, and confirm `r` asks before resets.
   For 013: play a few moves, leave the game, reopen it, undo twice.
4. **Backlog, none urgent**:
   - Board semantics for screen readers: its own slice, deliberately placed after the
     Android toolchain so TalkBack can judge it. There is no `Semantics` in `lib/` today.
   - If 2× text feels cramped, cap the coach bar's growth before shrinking the grid further.
5. **Committing from here on.** Commit per slice or per session on `coach-and-export` and
   push to `origin`, which is your fork. Never push to `main` and never create a `v*` tag:
   `fork-android.yml` publishes a signed release on tags. A branch push only runs analyze
   and tests.

## Gotchas worth remembering

- **Riverpod** throws if another provider is modified inside `onDispose`. That is why
  `activeSaveKeyProvider` is never cleared there; every entry point sets it explicitly.
- **Saves carry the undo history.** `GameAction.toJson` / `GameAction.fromJson` encode every
  action type, and an all-empty coach-elimination snapshot is omitted (≈242 bytes saved per
  action). A 300-action notes-heavy game measured 30,777 bytes, ~102 B/action. An unknown
  action type throws rather than being skipped. Saves written before 013 have no `history`
  key and load with an empty history.
- `fromJson` deliberately does not restore `puzzleComplete`: restoring it would disable the
  action row on open while the solved overlay never appears. Completed saves are deleted on
  exit instead.
- **Save keys** in `gameBox`: a difficulty name, `import:<id>`, plus the meta keys
  `__imports` (index) and `__lastPlayed` (a game key). `settingsBox` holds `difficulty_key`
  and `theme_onboarding_seen`.
- **Imports** live outside the difficulty slots by design; `SaveGameService.save` takes a key
  and `deleteKey` prunes the import index.
- **Coach soundness** is enforced two ways: a brute-force oracle over synthetic candidate
  boards, and a coverage test that walks the solver's path. The oracle is gated to positions
  with ≤45 empty cells because refuting a digit on an empty board is expensive.
- **Turbot Fish** in `lib/domain/engine/techniques/` used to target pattern cells; fixed in
  007 with a regression test.
- **Grid sizing** is a heuristic in `grid_widget.dart`: 220 px is the pad/actions budget, and
  in portrait the grid now shrinks rather than falling back to the screen width.
- The `startup` flow shows the theme sheet from a post-frame callback in `HomeScreen`; the
  flag is written when the sheet's future completes, whatever way it was dismissed.
- **Keyboard shortcuts** live in the `Focus.onKeyEvent` in `game_screen.dart`. Navigation is
  always live; every action key is inert on a completed puzzle. `confirmReset` and
  `showHintSheet` are top-level functions in `action_row.dart` so the toolbar and the keys
  share one path. Tooltip key hints come from `showKeyboardHints` / `shortcutHint` in
  `presentation/shared/utils.dart` and follow the host OS on web.
- **`coach_soundness_test.dart` retries** a difficulty up to five times while it has checked
  no elimination, because puzzles are generated unseeded and a singles-only walk never
  reaches one. Attempts without oracle work are cheap; do not read the retry as tolerance for
  an unsound elimination.
