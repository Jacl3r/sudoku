# 013 — Persisted undo history

Parent: this session's ideation (2026-11-04). The PRD step was skipped on purpose: the
decisions are small, already recorded in the conversation, and no product surface changes.
Depends on: none
Blocks: none (independent of 014)

## Why

Undo stops at the point where the app was last saved. `GameState.toJson` never writes
`history` and `GameState.fromJson` hard-codes `history: const []`, so resuming a game gives a
frozen board: the moves are still visible, but none of them can be taken back. The engine
already records everything an undo needs — previous value, previous notes, and the coach
elimination ledger before the action.

## Scope

- `GameAction` gains JSON encoding and decoding for all five variants: `DigitAction`,
  `PencilAction`, `EraseAction`, `AutoNotesAction`, `CoachNotesAction`.
- `GameState.toJson` writes `history`; `fromJson` restores it. A save with no `history` key
  loads with an empty history, which is every save written before this slice.
- An action whose coach-elimination snapshot is entirely empty omits that snapshot and
  decodes to an empty list, which the engine already treats as an all-empty ledger. Saves stay
  roughly half their naive size.
- The whole history is persisted. No cap, no pruning, no new setting.
- Import saves get the same behaviour for free, because they share `SaveGameService.save`.

## Out of scope

- Any limit on in-memory history, or a "how much undo" preference.
- Restoring `puzzleComplete` from a save. Completed games are deleted on exit, and a restored
  `puzzleComplete: true` would disable the action row on open without the solved overlay ever
  appearing. Left as-is; noted below.
- Migrating existing saves. They load with empty history, exactly as today.
- Changing when saves are written.

## Acceptance criteria

- [x] A game saved after several digit entries, note toggles and erases undoes each move in
      reverse order after being loaded, restoring grid values and notes.
- [x] A coach elimination step undoes as one step after a load, and the ledger returns to its
      previous state.
- [x] A save written without a `history` key loads with an empty history, and Undo does
      nothing instead of throwing.
- [x] A save whose actions changed no coach eliminations holds no elimination snapshot per
      action.
- [x] A completed game is still deleted on exit rather than resumed.
- [x] `flutter analyze` and `flutter test` are green and the web build succeeds.

## Findings (2026-11-04)

- `GameAction` now owns its own JSON (`toJson` per variant plus `GameAction.fromJson`), the
  same way `GameState` does. An unknown `type` throws instead of being dropped, so a corrupt
  save fails loudly rather than silently shortening the undo stack.
- Every action type gained value equality and hashing. `GameState.==` compares history with
  `listEquals`, which was comparing action instances by identity, so a round-tripped history
  could never equal the original. Note maps and sets compare by content, and hashes are
  order-independent.
- Elimination snapshots are omitted entirely when every cell is empty, and decode to
  `const []`. `GameEngine._copyEliminations` already pads a short ledger with empty sets, so
  the engine needs no change.
- **Measured** on a synthetic 300-action notes-heavy game: 30,777 bytes, about 102 bytes per
  action. Including an all-empty 81-cell snapshot would add 242 bytes to each action, taking
  the same game to roughly 100 KB. Saves are written on exit and pause, so the remaining cost
  is paid once and off the interaction path.
- Coach eliminations undo as one step because `CoachNotesAction` already snapshots notes and
  the ledger together; it needed only encoding, not new undo logic.
- `fromJson` still does not restore `puzzleComplete`; see the note below. No save is migrated:
  a file written before this slice simply has no `history` key.
- Verified: `flutter analyze` clean, **158 tests pass** (four new), web build green.

## Testing

Three existing seams, no new infrastructure:

- `test/domain/models/game_state_test.dart` — JSON round trip of a hand-built history that
  contains one of each action type; assert the restored history equals the original, and that
  removing the `history` key yields an empty history.
- `test/data/services/save_game_service_test.dart` — play a few moves through `GameEngine`,
  save, load, rebuild an engine from the loaded state, undo, and assert the grid and notes come
  back. This is the highest seam and the one that matters: it exercises Hive, the encoder and
  the engine together.
- `test/domain/engine/game_engine_test.dart` — still green; undo semantics are unchanged.

Manual on web: play, leave the game, reopen it, undo twice.

## Notes

- Size: every action carries a full 81-cell elimination snapshot in memory, so a naive encode
  would add roughly 250 bytes per action even when nothing was eliminated. Omitting empty
  snapshots is the difference between a save that grows visibly and one that does not. Measure
  a synthetic long game and record the number in the Findings, so a later change that
  re-inflates the save is visible.
- `GameState` includes `history` in `==` and `hashCode`, and history elements now compare by
  value too, so tests can compare histories directly. Whole-state comparison is still not
  available: `SudokuGrid` has no value equality, so a restored state never equals the original
  even when every field matches.
- The action list is self-contained: actions reference cell indices, values and note sets only,
  so restoring them against the saved grid needs no versioning or repair pass.
- Adjacent gap, deliberately untouched: `fromJson` does not restore `puzzleComplete`, so a
  completed save that survives an app kill reopens as a solved board with an empty action
  state. If that ever bites, fix it by routing the restored save through the same
  "completed" path rather than by persisting the flag.
