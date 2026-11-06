# Handoff — session diary

Read this first in a new session. It explains what the project is, how we work, where the
state lives, and what to pick up next.

Last updated: 2026-11-04

## What this project is

A personal fork of `likhithpraveenk/sudoku` (Flutter), used as a daily driver and a place to
tinker. Two features were added on top of upstream: a staged solving-technique **coach**, and
an **export** sheet that turns a stuck board into a prompt for an AI. The fork installs next
to the F-Droid build (`com.jacl3r.sudoku`, label "Sudoku+").

Ground rules (also in `AGENTS.md`): work stays on `daily-driver`, never `main`; never
create `v*` tags, because `fork-android.yml` publishes a signed release on them; keep the UI
clean and light.

## How we work

Four steps, each producing a file:

1. **ideation** — an interview until every decision is made. No file.
2. **to-spec** — one PRD in `docs/prd/`, grounded in the code.
3. **to-tickets** — one plan file per vertical slice in `docs/plans/NNN-slug.md`, with parent,
   dependencies, scope, acceptance criteria, testing seam and notes.
4. **implement** one slice, tick its acceptance criteria, and append a Findings section
   describing what changed and what was discovered.

The skills live in `~/.agents/skills/` and are invoked explicitly. `to-spec` and `to-tickets`
accepted `to-prd` and `to-issues` on 2026-11-06; `AGENTS.md` records the tracker
configuration that keeps their output in `docs/prd/` and `docs/plans/`.

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
- **Android toolchain is installed** (2026-11-04): Android Studio 2026.2.2 from Homebrew with
  its bundled JDK 25, and the SDK at `/Users/jacler/Library/Android/sdk` with platform-tools
  37.0.1, build-tools 37.0.0 and platform android-37.0. Gradle fetched NDK 28.2, build-tools
  36 and platforms 35/36 on the first build. `flutter build apk --debug` succeeded and wrote
  `build/app/outputs/flutter-apk/app-debug.apk`; the first run took about 12 minutes with
  downloads. Nothing has run on the phone yet.

## Where things stand

Two PRDs, fourteen slices, all implemented:

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
| 014 | Dead `sharePuzzle` removed |

Current numbers: **154 tests**, `flutter analyze` clean, web build green.

A separate **`multiplayer`** branch exists for a private browser-only co-op experiment (PRD
`docs/prd/multiplayer.md`, slices 015–018 in `docs/plans/`). It never merges into this branch
and is never released; this branch's app is unaffected by it. Nothing from it should be
cherry-picked here.

Slices 001–011 are committed and pushed to `origin/daily-driver` as **`564663b`** (53
files, +4090/−317); 012, 013 and 014 landed as follow-up commits on the same branch. The
branch is called `daily-driver` since 2026-11-05 (it was `coach-and-export`), and it has
**upstream v1.2.0 merged in** (`52fe721`), so it is no longer a release behind. The
fork's `main` tracks `upstream/main` exactly and only moves by fast-forward. One commit
per session on purpose: the slice docs carry the history, and the tree was tested as a
whole.

## Pick up here next session

1. **Phone acceptance pass (highest value).** The toolchain is installed and the debug APK
   builds. Connect the Pixel 9, enable USB debugging, then `flutter run --profile` and measure
   the checks that are still unmeasured:
   - `nextCoachStep` latency on the device (desktop VM was p95 0.8 ms, max 3.4 ms);
   - the coach bar at 360×640 and at 2× text (grid lands near 168 px — tight);
   - the Android share sheet;
   - the first-run theme sheet on a real install.
2. **Manual web pass** if the phone is not ready: settings sections and previews; the
   five-page carousel, pips and action swapping; the first-run sheet after clearing site
   data; and slice 012 — select a digit and compare the matches, open the coach to a pattern
   to confirm its tint survives, walk every shortcut, and confirm `r` asks before resets.
   For 013: play a few moves, leave the game, reopen it, undo twice.
3. **Backlog, none urgent**:
   - Board semantics for screen readers: its own slice, now that a device can judge it.
     There is no `Semantics` in `lib/` today.
   - If 2× text feels cramped, cap the coach bar's growth before shrinking the grid further.
4. **Committing from here on.** Commit per slice or per session on `daily-driver` and
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
- **Turbot Fish**: slice 007 "fixed" it to skip pattern cells, but that was not a bug. Any
  cell that sees both tips can lose the digit, base cells included, and the only board
  where the old code differed is a contradictory one. The skip is merely conservative and
  stays here; it must not go upstream. See `docs/upstream-contribution.md`.
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
- **Android tool details.** `android/local.properties` and `android/key.properties` are both
  gitignored and must stay out of commits. A local release build without a keystore warns
  "No signing credentials found" and produces an unsigned APK; a signed daily driver needs its
  own keystore, and `v*` tags still must not be created.
- **`flutter doctor` reports "Android license status unknown"** even though the build works:
  the new `sdkmanager` no longer implements `--licenses`, and Flutter still parses for it. The
  eight licence files are in `~/Library/Android/sdk/licenses`. Do not chase this warning.
- **Phone testing shortcuts:** `adb shell settings put system font_scale 2.0` (reset with
  `1.0`) for 2× text, and `adb shell wm size 720x1280` with `adb shell wm density 320` for a
  360×640 logical viewport (reset both with `wm size reset` and `wm density reset`). Use
  `flutter run --profile`, never debug, when timing the coach.
- **PATH:** add
  `/Users/jacler/flutter-3.47.0/flutter/bin:/Users/jacler/Library/Android/sdk/platform-tools`
  if you want `flutter` and `adb` bare. Keep the pinned 3.47.0 tree first; the unused 3.47.9
  tree at `/Users/jacler/flutter` should be deleted.
