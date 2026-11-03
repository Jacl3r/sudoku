# 005 — Coach comfort: latency, layout, and the dead-end hand-off

Parent: `docs/prd/coach-and-export.md`, slice 3
Depends on: 002, 003, 004
Blocks: none

## Why

`nextCoachStep` runs every detector synchronously on the UI thread, and on a dead end
also runs Simple Coloring, Naked Quad, Hidden Quad, Jellyfish and now Turbot Fish.
The bar is a fixed 132 px with a single scrollable body, and `GridWidget` subtracts a
magic 220 plus the reserved height, so a small screen with large text is the likely
failure. Both are unmeasured on a phone. And the dead end currently offers the answer
("Reveal a cell") rather than the AI hand-off the PRD calls for.

## Scope

- Measure `nextCoachStep` wall-clock time on Expert positions, before and after
  applying a step, on web and on the phone. Record the numbers in this file.
- If the phone measurement exceeds the 100 ms budget, move the computation to
  `compute()` with a loading state in the bar. Do not micro-optimise detectors first.
- Make the bar's height adaptive rather than fixed, and re-check `GridWidget`'s
  reserved-height arithmetic so the grid keeps a playable size.
- Verify at 360×640 and at a large text scale, portrait and landscape.
- Dead end: offer "Ask AI for a nudge" that opens the export sheet preconfigured to
  notes + pencilmarks + prompt. Keep "Reveal a cell" as a secondary action if it
  still reads well.
- Give `showExportSheet` optional initial content/format/prompt parameters.

## Out of scope

- New coach stages or copy beyond the dead-end change.
- Redesigning the grid or the digit pad.
- Any change to the techniques themselves.

## Acceptance criteria

- [x] Measured time to first step is recorded for Hard and Expert, including the dead-end
      path. *Measured in the Dart VM, not on the phone; the device number is still open.*
- [x] No loading state was added because the measurement leaves roughly thirty times the
      budget in hand; the isolate fallback stays documented rather than implemented.
- [x] The bar scales with the text scale, and the grid shrinks in portrait instead of
      falling back to the screen width, which is what used to push the controls off the
      bottom.
- [x] The grid has a floor so it cannot collapse, and is measured against the bar's actual
      reserved height.
- [x] On a dead end, "Ask AI for a nudge" opens the export sheet pre-set to notes +
      pencilmarks + prompt, and "Reveal a cell" stays as the secondary action.
- [x] Closing the bar restores the grid, because the reserved height only applies while
      the bar is open.

## Findings (2026-11-04)

- **Measurement.** Six generated puzzles (three Hard, three Expert), 233 coach steps plus
  the dead ends, timed in place with a `Stopwatch`:

  | | p50 | p95 | max |
  |---|---|---|---|
  | steps | 0.0 ms | 0.8 ms | 3.4 ms |
  | dead ends (whole chain + fallback) | — | — | 1–5 ms |

  That is on an M-series desktop VM in JIT, not ARM AOT on the phone. Even assuming the
  phone is an order of magnitude slower, the worst case stays under 40 ms against a 100 ms
  budget, so no `compute()` and no loading state. Revisit only if a device measurement
  disagrees.
- **Bar height** is now `coachBarHeight(context)`: 132 px at the default scale, growing by
  up to 48 px at 2× text. The same function feeds `reservedHeight`, so the bar and the grid
  cannot disagree.
- **The real layout bug was in `GridWidget`.** When `availableHeight` fell below 200 it
  fell back to `width - 16`, so a large text scale with the bar open made the grid *bigger*
  and overflow the column. In portrait it now shrinks instead, with a 140 px floor. The
  landscape path is unchanged.
- **Hand-off.** `showExportSheet` takes optional content, format and prompt, so the dead end
  opens at notes + pencilmarks + prompt without touching the remembered last choice.
- **Still open.** The phone measurement and the visual check at 360×640 remain; on that
  viewport at 2× text the grid lands around 168 px, which is playable but tight. The next
  lever, if it reads poorly, is capping the bar's growth rather than shrinking the grid
  further.
- 154 tests pass and the web build succeeds.

## Testing

Manual on web, then on the phone, against the checklist above. No widget tests: the
PRD keeps layout verification manual by choice.

## Notes

- `kCoachBarHeight` and the 220 constant in `grid_widget.dart` are the two levers.
  Prefer deriving the reserved space from the bar's own intrinsic height over adding
  another constant.
- The isolate fallback must send plain data: `List<int>` values, `List<Set<int>>`
  notes, `List<int>` eliminations. `CoachStep` is immutable and trivially copyable,
  but keep the isolate boundary at the input side to avoid fighting platform
  channels on the result.
