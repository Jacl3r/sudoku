# 017 — Presence and ownership

Parent: `docs/prd/multiplayer.md`, slice 017
Depends on: 015
Blocks: none

## Why

A shared board without presence feels like a haunted grid: cells change while you are looking
elsewhere, and nothing tells you whether your friend is working the same box. Co-op also needs
the small social fact of who placed what, or you cannot tell your own progress from theirs.

## Scope

- Presence: each client broadcasts its selected cell (throttled, not on every timer tick), the
  server relays it, and the other player's selection is drawn as an outline in their accent.
  Presence is ephemeral and never persisted.
- Ownership: the client folds the applied intent log into a cell → player map. A placement sets
  the owner; an erase, undo or restart clears or recomputes it. The map lives only in the
  co-op controller — `GameState` is unchanged, so saves and exports are unaffected.
- Cells filled by the other player show their digit in the theme's tertiary accent. The local
  player's digits and all notes stay as they are.
- A connection bar naming both players as present or absent, and a clear refusal screen for a
  third connection.
- The co-op screen must hold up at 360×640 and with 2× text, with the top bar out of the grid's
  way.

## Out of scope

- Names or avatars. Two fixed accents assigned by join order.
- Ownership on notes.
- Chat, reactions, or a move log in the UI.
- Any change to solo rendering.

## Acceptance criteria

- [ ] The friend's selected cell is outlined in their accent and moves as they move.
- [ ] Digits placed by the friend are in the tertiary accent; the player's own are unchanged.
- [ ] After an undo, an erase and a restart, ownership matches the resulting board.
- [ ] With the friend disconnected, their presence disappears and the board still reads.
- [ ] A third connection sees a clear "room full" state instead of a broken board.
- [ ] The grid, digit pad, action row and coach bar fit a 360×640 browser at 2× text.
- [ ] `flutter analyze`, all tests and the co-op web build pass.

## Testing

- `test/coop/ownership_test.dart` — folding a log of placements, erases and undos yields the
  expected owner map, including a restart that clears it.
- Manual, and not automated: cursor outline, accent colour, connection bar, third-player
  refusal, and the two viewport checks. This project has no widget tests by policy.

## Notes

- The ownership accent is chosen against the existing themes when this slice starts; do not add
  a new palette entry unless the theme has nothing suitable.
- When a digit is selected, the same-digit highlight sets the text colour to `onPrimary`, so
  ownership is briefly hidden on those cells. That is accepted in the PRD.
- Presence is sent from the co-op controller, not from widget build methods, or the timer tick
  would spam the socket.
