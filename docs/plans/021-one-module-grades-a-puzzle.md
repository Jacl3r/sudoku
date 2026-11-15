# 021 — One module grades a puzzle

Parent: `docs/prd/coach-and-export.md`
Depends on: 019, 020
Blocks: none

## Why

"How hard is this puzzle?" was answered in several places: a private rule in the generator,
the score table and bands, the coach walk, and a separate, weaker rule in the import. The
import labelled a puzzle by its hardest technique alone and never checked whether the solver
got stuck, so a chain puzzle that stalls after one pointing pair was filed as Medium. That is
the same mistake 019 fixed in the generator. It survived because the rule lived twice.

A technique's name was a string in the coach and its score sat in a table keyed by that
string. Renaming one silently turned its score into a default.

## Scope

- `lib/domain/grading/puzzle_grade.dart` is the one module that knows what makes a puzzle
  Easy, Medium, Hard or Expert. `gradePuzzle(puzzle)` returns a `PuzzleGrade`:
  - `difficulty`: the label. The hardest technique's level, or Expert when the solver had
    to guess.
  - `fits(target)`: whether the generator may hand the puzzle out as `target`.
  - `fitsLoosely(target)`: the original app's rule alone, for the generator's fallback.
  - `coachable` and `score`: for the report.
- The generator and the import both ask this module. The generator no longer holds any rule
  of its own.
- `CoachTechnique` is an enum with each technique's name and score. `CoachStep` carries the
  enum value. Its `technique` text is derived from it, so the two cannot drift.
- `puzzle_score.dart` is gone: the scores moved into the enum, the bands into the grading
  module.

## Two solver bugs found on the way

Both are in code from the original app and both only show on puzzles that need guessing.

- `solveGrid` reported success but returned only the cells that propagation had filled.
  Nothing in `lib/` used it, only tests. Fixed in `has_unique_solution.dart`, with a test.
- The import took its solution from `solveLogically(...).solvedGrid`. That solver's
  backtracking clears a cell without restoring the candidates it removed, so the search
  fails and the grid stays incomplete. An imported puzzle that needs guessing was stored
  with an incomplete solution, and every check against the solution was wrong for the
  empty cells. The import now takes its solution from the fixed `solveGrid`.
  `solvedGrid` itself is left as it is and no longer read by anything.

## Why `fits(target)` and not a single "typical" flag

The original rules overlap: a Hard-level puzzle with at most two opening singles is accepted
as Hard and as Expert. So "which level is this a good example of" has no single answer, and
the question has to name the level.

## Out of scope

- Grading with the coach alone and dropping the original solver from grading. The seam is
  now in place: that change would touch this module and no caller.
- A level on `CoachTechnique`. Nothing reads it until the coach grades alone.
- The duplicated "apply a coach step" in `GameEngine` and the coach walk.

## Acceptance criteria

- [ ] `puzzle_grade_test.dart` grades fixed puzzles: a singles-only puzzle is Easy, a puzzle
      the solver cannot finish is Expert.
- [ ] The generator report shows no puzzle that does not fit its difficulty.
- [ ] Importing a chain puzzle labels it Expert and stores a complete solution.
- [ ] `flutter analyze` and all tests pass.

## Notes

- An imported puzzle that used to show Medium or Hard can now show Expert. Games already
  saved keep the label they were saved with.
- The coach is only asked when a question needs it. Most dug puzzles fail on the solver's
  verdict, so walking every one would roughly double generation time.
