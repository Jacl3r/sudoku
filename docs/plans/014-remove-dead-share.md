# 014 — Remove the dead sharePuzzle

Parent: this session's ideation (2026-11-04). The PRD step was skipped on purpose; this is
dead-code removal.
Depends on: none (disjoint from 013)
Blocks: none

## Why

`PuzzleImportService.sharePuzzle` copies the current grid to the clipboard. Nothing in `lib/`
calls it: exporting a board is handled by the export sheet and `share_service`, which use the
full puzzle string plus its context. The method survives only in its own test, and it drags a
`flutter/services.dart` import into a service that is otherwise pure Sudoku logic.

## Scope

- Delete `sharePuzzle` from `PuzzleImportService`.
- Delete its test in `test/data/services/puzzle_import_service_test.dart`, and the imports that
  only that test needed.
- If `flutter/services.dart` becomes unused in the service, remove it too.

## Out of scope

- Any change to the export sheet, the share service, or the copy action.
- `loadPuzzleIntoGame`, its validation, and the import sheet.

## Acceptance criteria

- [x] `sharePuzzle` no longer exists and nothing references it.
- [x] Importing a puzzle still validates uniqueness, computes difficulty, and opens the game.
- [x] `flutter analyze` is clean and the remaining tests pass.
- [x] The test count drops by exactly one, and nothing else.

## Findings (2026-11-04)

- Removed the method, its test, the `flutter/services.dart` import and the two model imports
  that only the deleted test used. `loadPuzzleIntoGame` is untouched.
- Tests went from 159 to **158**; `flutter analyze` is clean. No web build was run: no UI or
  build input changed.
- Nothing referenced the method in `lib/`, so no call sites needed rewiring. Sharing a grid
  remains the export sheet's job.

## Testing

The existing import tests in `test/data/services/puzzle_import_service_test.dart` cover
`loadPuzzleIntoGame` and stay untouched apart from the removed case. Manual on web: import a
puzzle and confirm it still opens.

## Notes

- Low risk: the method has no callers, so there is no behaviour to preserve.
- Do not "rehome" it somewhere else. If sharing a grid is ever wanted again, the export sheet
  already owns that job.
