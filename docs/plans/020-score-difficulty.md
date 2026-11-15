# 020 — Difficulty by score

Parent: `docs/prd/coach-and-export.md`
Depends on: 019
Blocks: none

## Why

A difficulty was decided by the single hardest technique in the puzzle. Measured on 150
generated Hard puzzles: 89 had exactly one advanced step, the easiest was 56 singles plus one
Skyscraper, the hardest had six advanced steps and thirteen steps beyond singles. Both were
"Hard". Medium had the same problem at a smaller scale: nearly half were singles plus one
Pointing Pair.

## Scope

- Every coach step has a score by technique (`lib/domain/coach/puzzle_score.dart`). The
  numbers follow HoDoKu's defaults. A technique without an entry costs 100.
- A puzzle's score is the sum over the coach's own walk of it (`walkWithCoach`), so it
  counts what the player is shown, pattern by pattern.
- The generator keeps a puzzle only if its score is inside the band for the difficulty:
  Medium 780 to 1000, Hard 1100 to 1600. Easy and Expert have no band.
- The hardest-technique rule from upstream still applies. The band is an extra condition.
- The check shares the cap from 019: after 40 solver-approved puzzles it stops insisting.

## How the bands were chosen

From 150 generated puzzles per difficulty, before any band:

| Difficulty | min | p25 | median | p75 | p90 | max |
|---|---|---|---|---|---|---|
| Easy | 620 | 630 | 630 | 630 | 630 | 630 |
| Medium | 704 | 754 | 804 | 854 | 924 | 1134 |
| Hard | 904 | 1038 | 1188 | 1378 | 1548 | 2078 |

Medium below 780 is one locked-candidates step on top of singles. Hard below 1100 is one
advanced step on top of singles. The ceilings cut the top few percent. The Medium band kept
80 of 150 and the Hard band 91 of 150, so generation does roughly twice the work.

## Out of scope

- A band for Expert. Most Expert puzzles end in a coach dead end, so they have no score.
- Showing the score in the UI.
- Changing which technique belongs to which difficulty.

## Acceptance criteria

- [ ] `generator_quality_test.dart` reports no Medium or Hard puzzle outside its band.
- [ ] Hard generation stays unnoticeable on the phone.
- [ ] Hard feels even from game to game. This is the real test and only playing shows it.

## Notes

- The bands are a first setting from one measurement, not a finding. If Hard feels too
  heavy or too light, move the numbers in `scoreBandFor` and rerun the report.
- The coach tries Hidden Single before Naked Single, so almost every placement costs 14.
  That is why Easy sits at 630 (45 empty cells times 14).
- Renaming a coach technique without updating `techniqueScores` silently turns its score
  into 100. The report test fails when it sees a technique without an entry.
