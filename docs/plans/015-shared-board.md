# 015 — Shared board end to end

Parent: `docs/prd/multiplayer.md`, slice 015
Depends on: none
Blocks: 016, 017, 018

## Why

Two players cannot share a board today. Every `GameNotifier` is a single local writer: `build`
loads a Hive save or generates a puzzle, and its mutations land only in that browser. Nothing
in `lib/` opens a socket, so a move by one player has no path to the other.

This slice builds the smallest end-to-end version: one relay, two browsers, one board.

## Scope

- A relay server under `tool/` that serves `build/web` and one WebSocket on the same origin,
  because a single origin means a single tunnel later. One room: an ordered intent log with a
  monotonic sequence number, a two-player cap, a start timestamp, and JSON persistence under
  the already-ignored `.dart_tool/`. It sends a snapshot on join and broadcasts on change.
- A protocol of four intents: place digit, toggle note, erase, start game. Each carries what
  the actor's local settings resolved — digit-versus-note and `autoRemoveNotes` — because
  those settings are per-browser.
- A client transport (WebSocket) and a co-op controller over `GameEngine` that applies intents
  strictly in ascending order, with reconnect and log replay. No optimistic local echo.
- A co-op entry point, `lib/main_coop.dart`, that boots the same Hive boxes as `lib/main.dart`
  and shows the co-op screen instead of `HomeScreen`. A `--target` build keeps solo untouched.
- A co-op screen that reuses the existing board, digit pad, action row, settings and export
  sheet, plus a slim top bar with connection state and a New game control, and a difficulty
  sheet either player can use.
- The one change to shared code: `GameNotifier` gains a protected engine accessor and an
  engine-attachment hook, so a co-op subtype can apply remote intents to the engine directly
  without going through methods that re-read local settings. Solo behaviour must not change.
- Connection guards (PRD F7): the relay binds `127.0.0.1` only; every WebSocket upgrade must
  carry the room token from the printed URL and an `Origin` matching the tunnel host, since
  WebSocket is exempt from CORS; messages are size-capped and decoded field by field with
  integers range-checked; the stored intent log is length-capped.

## Out of scope

- Undo, hint, auto-notes, coach step and restart syncing — slice 016.
- Presence visuals and ownership colours — slice 017.
- Building, tunnels and instructions — slice 018.
- Accounts, more than two players, chat, spectators.

## Acceptance criteria

- [ ] Two browsers on one server show the same puzzle and the same grid after each move.
- [ ] Digits, notes and erases made by either player appear on both, in the same order.
- [ ] A player who joins mid-game lands on the current board.
- [ ] Refreshing the browser rejoins the same board; restarting the server restores it from
      disk with the same moves.
- [ ] A third connection is refused rather than silently joining.
- [ ] A connection with a wrong or missing room token, or an `Origin` that is not the tunnel
      host, is refused; an oversized message is dropped and play continues.
- [ ] While the relay runs, nothing on the host listens beyond loopback.
- [ ] Either player can start a new game by choosing a difficulty, and both land on it.
- [ ] `flutter analyze`, every existing test, a web build with `--target lib/main_coop.dart`
      and the normal web build all pass.

## Testing

- `test/coop/room_test.dart` — intents are numbered in order; the cap refuses a third player;
  a snapshot reflects the log; a persisted room reloads identically; a new game clears the log.
- `test/coop/intent_test.dart` — every intent round-trips, with explicit cases for a note
  intent and for `autoRemoveNotes` set and unset.
- `test/coop/controller_test.dart` — two engines fed the same intents end in identical state;
  intents arriving out of order are buffered until the sequence is contiguous.
- Manual, and not automated: two windows against one local server.

## Notes

- The server cannot import the domain. `Puzzle`, `GameState`'s helpers and `CoachStep` import
  `package:flutter/foundation.dart`, so a plain Dart process would need a second implementation
  of the rules. The server stays a dumb ordered relay; intents are opaque JSON to it.
- No optimistic echo is a deliberate trade: a move lands after one round trip, which Sudoku
  tolerates, and ordering is what makes divergence structurally impossible.
- The protected accessor is the only solo-code change in this slice. The existing test suite is
  the guard that it changed nothing.
- Keep the room file in `.dart_tool/` so nothing runtime-generated can be committed.
