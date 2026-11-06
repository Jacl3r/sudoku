# 016 — The rest of the game syncs

Parent: `docs/prd/multiplayer.md`, slice 016
Depends on: 015
Blocks: none

## Why

Slice 015 makes digits, notes and erases shared. The app's actual solving loop also uses undo,
the hint sheet, auto-notes, the coach and restart. Until those sync, one player can undo into a
different board or reveal a cell the other never sees, and the boards drift apart exactly where
co-op is most useful.

## Scope

- Intents for undo, hint, auto-notes, coach step and restart, applied in the same ordered
  stream as 015's intents.
- Undo is one shared history: it removes the last action whoever made it, and both engines pop
  the same entry because their histories were built from the same intents.
- The coach intent carries the whole applied `CoachStep`, so the other client applies the same
  eliminations instead of recomputing them. It also carries `autoRemoveNotes`.
- The hint intent carries `autoRemoveNotes`; revealing a cell is deterministic from the shared
  puzzle, so the intent stays small.
- A shared room clock: the room records its start timestamp, a joining client seeds the
  engine's elapsed time from it, and both players and a late joiner see the same elapsed time.

## Out of scope

- Presence and ownership (017).
- Any change to how the coach computes steps, or to solo hint behaviour.
- Per-player undo. There is one history by decision.

## Acceptance criteria

- [ ] Undo pressed by either player removes the same move on both boards, including a move made
      by the other player.
- [ ] A hint reveal appears on both boards.
- [ ] Auto-fill notes produces the same notes on both boards.
- [ ] Applying a coach step produces the same notes and eliminations on both boards, and undoes
      as one step on both.
- [ ] Restart resets both boards to the same starting position.
- [ ] Both players display the same elapsed time, and someone joining ten minutes in sees
      roughly ten minutes, not zero.
- [ ] History created before a player joined can be undone by both.
- [ ] `flutter analyze`, all tests and the co-op web build pass.

## Testing

- `test/coop/intent_test.dart` — round trips for the new intents, including a `CoachStep`
  payload and `autoRemoveNotes` in both states.
- `test/coop/controller_test.dart` — two engines fed the same intent log remain equal, and an
  undo intent removes the same action from both; a coach intent applies identical notes and
  eliminations to both.
- `test/coop/room_test.dart` — the persisted start timestamp survives a reload.
- Manual: both windows, one move of each kind.

## Notes

- The temptation is to recompute the coach step on the receiving client. Don't: the applied
  step is the fact, and sending it keeps both boards honest even if a future detector changes.
- `GameNotifier.hint` and `applyCoachStep` read `settingsProvider.autoRemoveNotes`, which is
  why the intent must carry the actor's resolved value rather than letting each side re-read
  its own.
- If applying a coach step on the receiving side needs engine access that the notifier does not
  expose, use the accessor added in 015 rather than widening the public API.
