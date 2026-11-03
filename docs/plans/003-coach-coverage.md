# 003 — Cover everything the app's own solver can do

Parent: `docs/prd/coach-and-export.md`, slice 2
Depends on: 001, 002
Blocks: 005

## Why

`_fallback` in `lib/domain/coach/coach.dart` covers Simple Coloring, Naked Quad,
Hidden Quad and Jellyfish, but not Turbot Fish, which `allTechniques` uses at Hard
level. So there are positions the app's own solver can crack where the coach says
"No step found" — the coach undersells itself on exactly the boards the player
cares about.

## Scope

- Add `TurbotFish()` to the coach's fallback map, name and cell first. Upgrade it to
  a detector with pattern cells only if the name-only step reads badly on a real
  board.
- Add a coverage test: whenever `solveLogically` can still progress from a position,
  `nextCoachStep` returns a step.
- Make sure the fallback never proposes an elimination that the current candidate
  state does not hold (the existing `where((d) => b.has(...))` guard, verified).

## Out of scope

- X-Chain, XY-Chain and other chaining techniques.
- Drawing patterns for the fallback techniques.

## Acceptance criteria

- [x] The coverage test passes at every difficulty, walking the solver's own path
      (three generated puzzles each) rather than only the coach's path.
- [x] Where the app's solver cracks a position with Turbot Fish, the coach reaches
      the same deduction as Skyscraper or Two-String Kite. The raw `TurbotFish`
      fallback entry was not kept; see Findings.
- [x] The dead-end path still appears for positions that genuinely need chains.

## Findings (2026-11-03)

- The first coverage test compared the solver's candidates (derived from digits
  alone) with the coach's (digits minus the ledger). It failed at move 16 on Hard,
  because the solver kept re-reporting a pointing elimination the coach had already
  applied. The test now walks the solver's path and carries every `IndirectHint`
  into `coachEliminations`, so both sides see the same candidate state.
- `TurbotFish` was added to the fallback and then removed. Its row/row and col/col
  patterns are exactly the coach's Skyscraper, and coverage passes without it. It
  also scans every cell as a target except the two tips, so it can propose removing
  the digit from a pattern cell: with 5 confined to R1C1, R1C2, R2C1 and R2C3 it
  returns "remove 5 at R1C1", a base cell where 5 is still possible. Delegating to
  it would let the coach teach an unsound elimination.
- The invariant is "the coach always has a step", not "the same technique".
  Removing a single detector still passes, because another technique fires at the
  same position; this test is a dead-end guard, not a detector-priority test.

## Testing

`test/domain/coach/`: a loop that, for each generated puzzle, takes a position where
`solveLogically` reports progress and asserts `nextCoachStep` is non-null. Reuse the
existing helpers in `test/helpers/sudoku_grids.dart`.

## Notes

- The coverage invariant is the guard against the two technique implementations
  drifting apart. If a future technique is added to `allTechniques` and not to the
  coach, this test is what fails.
- Keep the timeout honest: generated puzzles plus the fallback are slow, so follow
  the existing `Timeout` pattern in `coach_test.dart` rather than trimming coverage.
