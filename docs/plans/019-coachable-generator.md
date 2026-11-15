# 019 — Puzzles the coach can finish

Parent: `docs/prd/coach-and-export.md`
Depends on: none
Blocks: none

## Why

The generator handed out puzzles its own solver could not finish. `_meetsTargetDifficulty`
looked at `highestDifficultyLevel` only and never at `bruteForceUsed` below Expert. Measured
on upstream `main` with 20 puzzles per difficulty: 6 of 20 Medium and 12 of 20 Hard needed
guessing. Those boards have one solution, but need techniques the app does not know
(W-Wing, XY-Chain, Empty Rectangle and longer chains). In play that is a coach dead end.

## Scope

- Below Expert, a puzzle the solver finished by brute force is rejected. This part is
  identical to the upstream-bound branch `fix/generator-stuck-puzzles`.
- Below Expert, the generator also walks the puzzle with the coach (`coachCanFinish` in
  `lib/domain/coach/coach_walk.dart`) and rejects it if the coach hits a dead end.
- The coach check stops after `coachAttemptLimit` solver-approved puzzles (40), so a gap in
  the coach can slow generation down but cannot hang it.
- Expert is unchanged: it may still be harder than the solver and the coach.

## Out of scope

- New coach techniques (W-Wing, XY-Chain, Empty Rectangle).
- Changing what Expert means, or how wide the Hard band is.
- Any UI.

## Acceptance criteria

- [ ] `generator_quality_test.dart` reports 0 stuck puzzles and 0 coach dead ends for Easy,
      Medium and Hard.
- [ ] Generation time for Hard stays unnoticeable on the phone.
- [ ] `flutter analyze` and all tests pass.

## Notes

- Written without a local Flutter toolchain and checked by the fork's CI only. Run
  `dart format .` and the tests locally before relying on it.
- If the quality test ever reports coach dead ends, the cap was hit: the coach is missing
  something the solver can do, and the coverage test should be extended to show what.
