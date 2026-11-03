# PRD — Coach, AI export, and daily-driver polish

Status: ready for slicing
Branch: `coach-and-export` (personal fork)
Work item target: `docs/plans/NNN-slug.md` (see `AGENTS.md`)

## 1. Problem

The upstream app is good at playing Sudoku but offers nothing for learning it, and
nothing for getting unstuck with outside help. Three pain points, from the owner's
perspective:

1. **Being stuck has one exit: the answer.** The only hint is "Reveal a cell",
   which places a correct digit in the first empty cell
   (`GameEngine.revealHint`). There is no technique name, no area to look at and no
   reasoning — so a player who wants to learn has nothing to learn from.
2. **No way to ask an AI with context.** There is no export, so helping yourself
   with an AI means transcribing an 81-cell board by hand.
3. **Resuming costs four taps.** `difficultyProvider` returns `.easy` on every cold
   start and is not persisted. The Continue button in `home_screen.dart` only
   renders for the selected difficulty, so an Expert save is invisible until the
   selector is clicked back to Expert every time.

The existing branch proves the ideas but is not safe to rely on daily:

- `CoachBoard.fromPlayer` intersects `possibleCandidates` with the player's notes.
  Intersection is only sound when notes are complete. For a player who notes a few
  cells — the normal case — the coach can report a Naked Single that does not exist
  and then **apply a wrong digit**. The existing tests cannot catch this because
  they only run with `autoFillNotes()`.
- Once the coach reasons on the full candidate set, an applied elimination would not
  change its input at all, so it would re-offer the same step indefinitely.
- The coach's fallback omits Turbot Fish, which the app's own solver uses at Hard
  level. Measured in slice 003: the coach's Skyscraper and Two-String Kite already
  cover it on real positions, so coverage holds without delegating to the upstream
  implementation, which can target a pattern cell.
- Applying an elimination to a cell with no notes materialises notes in that cell
  and nowhere else.
- Nothing has been run on a phone, so layout and latency are unverified.

## 2. Goals

- A coach that is **never wrong**: every step is valid for the current position, and
  Apply cannot leave an invalid board.
- A coach that **teaches**: technique first, then area, then pattern.
- A coach that **keeps up**: a new step after every applied step, never a repeat.
- **One tap back** to the most recent game, on the difficulty actually played.
- An export that **lands a usable prompt** in an AI chat: "give me a nudge, not the
  solution".
- No noticeable pause, and a coach bar that fits a phone without wrecking the grid.

Non-goals: solving the puzzle for the player, teaching every advanced technique, web
as a shipped target, upstream contribution.

## 3. Actors and user stories

Actor: the owner — a daily player who usually plays Expert, wants to understand
techniques rather than receive digits, and occasionally asks an AI for a nudge.

- When I am stuck, I ask for the next step and get a technique name, then the area to
  look at, then the pattern and what it removes, so I have a chance to spot it myself
  before being told.
- When I press Apply, the board changes exactly as the explanation said, never becomes
  invalid, and one undo takes the whole change back.
- When I ask again after applying, I get the *next* step, not the same one.
- When the coach has nothing, I am told plainly and offered an AI hand-off that opens
  the export already set up for a nudge.
- When I open the app, one tap takes me back to the puzzle I was playing, whatever
  difficulty I selected last, and a new game starts on that difficulty.
- When I add a note by hand, the coach bar does not evaporate.

## 4. Functional scope

### F1 — Coach correctness

- Reason on the full candidate set derived from placed digits only. Notes are
  display-only and never feed the reasoning.
- Never propose a placement that contradicts `puzzle.solution`, and never propose an
  elimination that is unsound for the current candidate state.
- Record applied eliminations on the game (F2, §5).
- Keep the existing mistake detection: a wrong digit first, then a note that hides the
  solution digit.
- Cover every technique the app's own solver can apply, including Turbot Fish.

### F2 — Coach experience

- Keep the three-stage reveal (technique → area → pattern) and the cell tinting,
  marking and striking.
- Apply: placements place the digit; eliminations remove the digit only from cells
  that already have notes, and are recorded regardless — so a digits-only player
  never gets invented notes and never gets repeating advice.
- After Apply the bar closes; the next ask starts a fresh step.
- Dead end: say so, and offer an AI hand-off through the existing export sheet.
- Layout: the bar fits a 360×640 phone and large text scale, portrait and landscape,
  without squeezing the grid into unplayability.

### F3 — Export

- Keep the content × format matrix and the prompt.
- Close the gaps found in review: the share fallback leaving Copy stuck on "Copied";
  the "works with HoDoKu" claim on the pencilmark format; link-plus-prompt sharing a
  prompt that contains a URL; no export once the puzzle is complete.
- Applied eliminations are reflected in exported candidates.

### F4 — Home resume

- A resume card above the difficulty selector for the most recently played save,
  showing difficulty, elapsed time and progress, one tap to continue.
- The difficulty selector restores the last played difficulty.
- No card when there is nothing to resume or the most recent save is complete.

### F5 — Run and verify

- Flutter SDK installed locally; the app runs in Chrome as the functional harness.
- The app runs on the owner's Android phone via the fork CI signed APK and is checked
  against §9.

### F6 — Easy-wins screening (deferred)

After F1–F5, a pass over the app for cheap, high-value fixes. The clean, lite feel is
the priority: every proposal must justify its weight, not just its correctness.
Scoped separately once the main work lands.

## 5. Implementation decisions

- **Coach candidates.** `CoachBoard` is built from `possibleCandidates` alone.
  `nextCoachStep` also takes the recorded eliminations and excludes them. Notes keep
  their current role: rendering, and deciding which cells an elimination may touch.
- **Elimination ledger.** `GameState` gains `coachEliminations` (81 × digit set,
  stored like `notes`), included in `toJson`/`fromJson` (absent means empty, so
  existing saves load) and in `==`/`hashCode`.
- **Undo.** One history entry captures `previousNotes` *and*
  `previousCoachEliminations`, replacing the current `AutoNotesAction` usage in
  `GameEngine.applyCoachStep`, so a single undo restores both.
- **No repeats.** `nextCoachStep` filters candidate eliminations already present in
  `coachEliminations`. A step is only offered if it removes something new.
- **Applying eliminations.** Mutate `notes[i]` only where `notes[i]` is non-empty;
  always add the removed digits to `coachEliminations`. Never create notes.
- **Removing a placed digit invalidates the ledger.** Erasing a digit, replacing
  a digit, or turning a filled cell into a note all widen the candidate set, so
  recorded eliminations may no longer hold and a stale mask could produce a false
  single. Each of those paths clears the ledger, and `DigitAction`, `PencilAction`
  and `EraseAction` carry the previous one so undo restores it.
- **Turbot Fish.** Covered by the coach's own Skyscraper and Two-String Kite rather
  than by the upstream `TurbotFish` implementation. The coverage test proves parity:
  it passes without a Turbot Fish fallback entry. The upstream implementation scans
  every cell as a target except the two tips, so it can propose removing the digit
  from a pattern cell, which is unsound; the coach must not surface that.
- **Coverage invariant.** A test asserts that whenever `solveLogically` can still
  progress, `nextCoachStep` returns a step.
- **Coach staleness key.** `coachBoardKey` becomes placed digits plus recorded
  eliminations. Notes no longer invalidate the bar.
- **Dead-end hand-off.** `showExportSheet` takes optional initial content/format/
  prompt so the coach can open it preconfigured (notes + pencilmarks + prompt).
- **Last played marker.** `SaveGameService` writes `__lastPlayed` = the difficulty
  name on every save, and clears it when that difficulty's save is deleted. The
  resume card resolves it through `continueGameProvider` and hides itself when the
  save is gone or the board is full. No timestamp is stored; nothing needs it, and
  the marker is not a difficulty name, so `ContinueGameNotifier` ignores it.
- **Remembered difficulty.** Persist the selection under its own key in `settingsBox`
  and read it in `DifficultyProvider.build()`. Do not add it to `AppSettings`.
- **Performance.** Measure `nextCoachStep` on Expert positions. Budget: under 100 ms
  end-to-end on the acceptance phone. If missed, run the call on `compute()` with a
  loading state in the bar; do not micro-optimise detectors before measuring.
- **Fix the share fallback** in `export_sheet.dart` so the "Copied" state always
  resets, not only on the copy path.

## 6. Testing seams and expectations

Assert external behaviour, at the highest existing seam:

| Seam | Where | What it proves |
|---|---|---|
| `findCoachStep` on synthetic candidate grids | `test/domain/coach/`, in the style of `test/domain/engine/techniques_test.dart` | Each detector's eliminations are sound, including a brute-force oracle: an eliminated digit must appear in **no** completion of the candidate constraints |
| `nextCoachStep` + `applyCoachStep` walk | `test/domain/coach/coach_test.dart` | No step contradicts the solution; no step repeats after Apply; a puzzle can be walked to completion with the coach alone |
| Coverage | `test/domain/coach/` | Wherever `solveLogically` progresses, the coach has a step |
| `GameEngine` undo | `test/domain/engine/` | Notes and eliminations restore exactly, as one undo |
| `PuzzleExport.build` | `test/domain/export/` | Eliminations reflected; formats and prompt intact |
| Provider-level resume selection | `test/providers/` | Most recent save wins; card hidden when complete or absent |

No widget tests. Layout, latency, text scale and the Android share sheet are checked
manually on web and then on the phone.

## 7. Vertical slices

| # | Slice | Demo | Depends on |
|---|---|---|---|
| 1 | Run locally | App boots in Chrome; both branch features are reachable | — |
| 2 | Coach correctness | On Expert, the coach never lies and never repeats | 1 |
| 3 | Coach comfort | Bar fits a small phone; dead end offers an AI hand-off | 2 |
| 4 | Export final mile | Copy and share behave; the prompt lands in an AI chat | 1 |
| 5 | Resume card | One tap back into the last game; new game defaults to that difficulty | 1 |
| 6 | Easy-wins screening | A prioritised list of small fixes, then the approved ones | 1–5 |

## 8. Out of scope

- X-Chain, XY-Chain and other chaining techniques.
- New techniques beyond Turbot Fish.
- Widget or golden tests.
- Web as a shipped target; iOS and desktop as targets.
- Pushing upstream, or any change to `main`.
- Redesigning the home screen, the grid or the digit pad.

## 9. Acceptance checklist

Functional:

- A correct step is available in every game actually played on Hard and Expert, or the
  dead end is stated with an AI hand-off.
- Apply never leaves an invalid board; undo takes the whole step back.
- Asking again after Apply never repeats the same step.
- Export lands a prompt in an AI chat that asks for a nudge, not the solution.
- The resume card opens the most recent game in one tap; New Game starts on the last
  played difficulty.

Comfort:

- No noticeable pause when asking for a step on the acceptance phone.
- The coach bar is readable and usable at 360×640 and at large text scale, portrait
  and landscape, without pushing the grid below playable size.
- Undo, resume, notes, auto-notes and validation still behave as before.

## 10. Risks and open questions

- **Latency** — the detector chain plus the fallback (coloring, quads, jellyfish) runs
  synchronously on the UI thread. Measured in slice 2; isolate fallback if it misses
  budget.
- **Layout** — `kCoachBarHeight` is a fixed 132 px with a single scrollable body;
  large text scale is the likely failure. Slice 3.
- **Save compatibility** — there are existing saves on the phone. The new
  `coachEliminations` field must be optional on read, and the meta key must not
  disturb `ContinueGameNotifier`.
- **CI confidence** — `pubspec.yaml` pins `flutter: 3.47.0`, and
  `fork-android.yml` reads exactly that through `flutter-version-file`, so local and
  CI toolchains match once 3.47.0 is installed. What remains unverified is whether the
  branch's `check` job actually runs green.
- **Upstream `TurbotFish` can target a pattern cell.** Verified on a synthetic board
  where 5 is confined to R1C1, R1C2, R2C1 and R2C3: it returns "remove 5 at R1C1",
  a base cell where 5 is still possible. It sits in `allTechniques`, so the app's own
  solver can make the same deduction. The coach deliberately does not delegate to it.
  Worth reporting upstream and worth an item in the screening slice.
