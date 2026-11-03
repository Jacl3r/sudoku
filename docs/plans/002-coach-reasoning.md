# 002 — Make the coach's reasoning sound and repeatable

Parent: `docs/prd/coach-and-export.md`, slice 2
Depends on: 001
Blocks: 003, 005

## Why

The coach can currently hand the player a wrong digit. `CoachBoard.fromPlayer`
builds candidates as `possibleCandidates(...) ∩ notes`, which is only sound when
notes are complete; partial notes create false Naked and Hidden Singles. With
`Apply` one tap away, that turns a leaning aid into a mistake generator.

It also cannot move on: once it reasons on the full candidate set, applying an
elimination changes nothing it reads, so it re-offers the same elimination forever.
And applying an elimination to an un-noted cell currently materialises notes in
that one cell, which looks broken and was never requested.

## Scope

- Build `CoachBoard` from `possibleCandidates` alone. Notes stop feeding reasoning;
  they stay as display and as the gate for where eliminations may be applied.
- Add `coachEliminations` (81 digit sets, stored like `notes`) to `GameState`,
  including `toJson`/`fromJson` with absent-means-empty for existing saves, and
  `==`/`hashCode`.
- `nextCoachStep` receives the eliminations and filters any step that removes
  nothing new.
- Add a history entry capturing both `previousNotes` and
  `previousCoachEliminations`, replacing the `AutoNotesAction` usage in
  `GameEngine.applyCoachStep`, so one undo reverses the whole step.
- `applyCoachStep` for eliminations: mutate `notes[i]` only where `notes[i]` is
  non-empty; always record the removed digits in `coachEliminations`; never create
  notes.
- `coachBoardKey` becomes placed digits plus recorded eliminations. Editing a note
  no longer closes the bar.
- `PuzzleExport.candidates()` excludes recorded eliminations, so exports match what
  the player has actually ruled out.

## Out of scope

- Turbot Fish and the coverage invariant (003).
- Bar layout and latency (005).
- Any change to the four "mistake" paths other than keeping them working.

## Acceptance criteria

- [x] With deliberately partial notes, `nextCoachStep` never returns a placement
      that contradicts `puzzle.solution`.
- [x] Walking a generated puzzle with the coach alone reaches completion without a
      single placement or elimination that contradicts the solution.
- [x] Asking for a step twice, with an applied elimination in between, never returns
      the same elimination again.
- [x] On a digits-only board, applying an elimination leaves every cell's notes
      untouched; the elimination is still recorded.
- [x] On a board with notes, the eliminated digit disappears only from cells that had
      notes.
- [x] One undo reverses both the note removals and the recorded eliminations.
- [x] A save written before this change still loads, with an empty elimination ledger.
- [x] Editing a note while the coach bar is open does not close it.

## Testing

| Seam | File | Asserts |
|---|---|---|
| `findCoachStep` on synthetic candidate grids | `test/domain/coach/` | Each detector's eliminations are sound; the brute-force oracle rejects any digit that appears in a completion of the candidate constraints |
| `nextCoachStep` + `applyCoachStep` walk | `test/domain/coach/coach_test.dart` | No contradiction with the solution; no repeat after Apply; a puzzle can be walked to completion |
| `GameEngine` undo | `test/domain/engine/` | Notes and eliminations restore exactly, as one undo |
| `PuzzleExport.build` | `test/domain/export/` | Eliminated digits are absent from exported candidates |

## Notes

- A uniqueness-based oracle is useless here: on a unique-solution puzzle, forcing a
  non-solution digit always yields zero solutions, so it only re-tests "not the
  solution". The oracle has to run on candidate-constrained synthetic boards.
- `GameState.fromJson` currently drops `history`; the elimination ledger must still
  survive a restart, which means persisting it rather than deriving it from history.

## Findings (2026-11-03)

- No-repeat falls out of the input: `CoachBoard.fromState` removes recorded
  eliminations from the mask, so a detector cannot re-derive what is already gone.
  There is no post-filter over detector output.
- **Removing a placed digit invalidates the ledger.** Removing a digit widens the
  candidate set, so deductions recorded against the old set may no longer hold, and
  a stale narrow mask could produce a false single. Three paths remove a digit:
  `erase`, an `inputDigit` that overwrites a value, and `toggleNote` on a filled
  cell (which clears it). All three clear the ledger, and `DigitAction`,
  `PencilAction` and `EraseAction` capture the previous one so undo restores it.
  Erasing notes from a cell with no digit leaves the ledger alone.
- `CoachNotesAction` replaces `AutoNotesAction` for coach moves and restores notes
  and ledger together, so one undo reverses the whole step.
- The soundness oracle runs every detector at each position of a real coach walk
  once at most 45 cells are empty; earlier positions are too expensive to refute and
  produce no eliminations. The last run verified 632 eliminations across a Hard and
  an Expert puzzle. The test asserts the count is non-zero so it cannot pass
  vacuously.
- `coachEliminationsAt` pads missing entries, so hand-built `GameState` values and
  old saves both behave.
- 137 tests pass (up from 125).
