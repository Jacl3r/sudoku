# 004 — Export: close the last-mile gaps

Parent: `docs/prd/coach-and-export.md`, slice 4
Depends on: 001
Blocks: 005 (the coach's dead-end hand-off reuses this sheet)

## Why

The export content is good, but the ways out of it are rough: the share fallback
leaves the Copy button stuck on "Copied", the pencilmark format claims a
compatibility it does not have, the link-plus-prompt combination offers a button
that does not match what it will send, and the sheet is unavailable once the puzzle
is solved — the moment you most want to share a finished board.

## Scope

- `_share` in `lib/presentation/widgets/export_sheet.dart` must reset the "Copied"
  state the same way `_copy` does, including when the share sheet is unavailable.
- Reword the `ExportFormat.pencilmarks` description: it is a readable pencilmark
  grid, not a HoDoKu import string.
- Make the action offered match the payload: "Open" only for a bare link; anything
  carrying a prompt is shared or copied.
- Allow the export sheet on a completed puzzle; remove the
  `!game.puzzleComplete` gate in `game_screen.dart`.
- Confirm the prompt never contains the solution and always asks for a nudge rather
  than an answer.
- Recorded coach eliminations appear in exported candidates (depends on 002 for the
  data; if 002 lands later, leave the wording in place and follow up).

## Out of scope

- Deep links into specific AI apps.
- Adding formats or content options.
- Any change to the prompt's structure beyond clarity fixes.

## Acceptance criteria

- [x] After a share fallback, the button returns to "Copy" within a couple of
      seconds, exactly as after a copy.
- [x] No user-visible text claims HoDoKu or solver import compatibility.
- [x] For a bare link the primary action opens the browser; for anything containing a
      prompt it shares or copies, and never opens a raw URL disguised as a board.
- [x] The export icon is available on a completed puzzle and exports the full board.
- [x] On an unsolved board the prompt asks for a nudge before an explanation; on a
      completed board it asks for the solution to be checked instead of claiming to be
      stuck.

## Findings (2026-11-03)

- `_copy` and `_share` now share one `_flashCopied` helper, so the share-sheet
  fallback resets the label like the copy path does. A successful share shows no
  state change; the system sheet is the feedback.
- The action matrix was already correct: `Open` only for a bare link, `Share` for
  everything else including link-plus-prompt. No change was needed.
- Exporting a completed puzzle with the old prompt read as nonsense ("I am stuck" on
  a solved board), so the prompt now has a completion variant when the exported
  digits contain no gaps. This was not in the original scope but falls straight out
  of enabling the button after completion.
- 140 tests pass. The export suite covers recorded eliminations and the completed
  prompt; the sheet's button state and the Android share sheet remain manual.

## Testing

`test/domain/export/puzzle_export_test.dart` covers the text. The sheet's state
handling, the Android share sheet and the browser path are manual: web first, then
the phone.

## Notes

- `shareText` in `lib/data/services/share_service.dart` returns false on web and on
  any platform where the Android channel is missing, and it has already copied by
  then. The button state should follow the returned value, not assume success.
- Keep the sheet's remembered last choice per session; it is a nice touch and costs
  nothing.
