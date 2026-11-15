# 022 — Expert is never lighter than Hard

Parent: `docs/prd/coach-and-export.md`
Depends on: 021
Blocks: none

## Why

Expert had no score rule at all. The original rule accepts two kinds of puzzle as Expert: one
the solver cannot finish, and a Hard-level puzzle with at most two opening singles. The second
kind could score below Hard's floor. Seen in the report: an Expert puzzle that was singles plus
one Skyscraper, score 928, while Hard starts at 1100.

A third kind showed up while checking the solver. The original solver has no Two-String Kite
(its Turbot Fish only pairs two rows or two columns), so it gets stuck on puzzles the coach
finishes with one kite. Those were handed out as Expert whatever they scored.

## Scope

- An Expert puzzle the coach can finish must score at least Hard's floor (1100). A coach dead
  end is still accepted as Expert.
- `solveLogically` now returns a complete `solvedGrid` after guessing. Its own backtracking
  cleared cells without restoring candidates and left the grid half empty. It now takes the
  rest from `solveGrid`. Nothing reads `solvedGrid` today, so this only removes a trap.
- The generator test now checks that every generated puzzle carries the full, unique solution.

## What Expert is after this

Measured on 60 generated Expert puzzles before the floor:

| Kind | Puzzles |
|---|---|
| Coach dead end, needs chains | 41 |
| Hard by technique, tight opening | 16 |
| Solver stuck, coach finishes with a kite | 3 |

The floor only removes the light ones from the last two rows. Expert is still mostly coach
dead ends. That changes only when the coach learns chains (W-Wing, XY-Chain, Empty Rectangle).

## Out of scope

- An upper limit for Expert.
- Making Expert coachable only. It would turn Expert into "Hard with a tight opening".
- Teaching the solver a Two-String Kite. The fork's Turbot Fish also still carries the
  conservative skip from `docs/upstream-contribution.md`; it matches what the coach's
  Skyscraper does, so the two agree.

## Acceptance criteria

- [ ] No generated Expert puzzle the coach can finish scores below 1100.
- [ ] Expert generation stays unnoticeable on the phone.
- [ ] `flutter analyze` and all tests pass.
