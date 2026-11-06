# Multiplayer — private live co-op

Status: planned, not started.
Branch: `multiplayer`, cut from `daily-driver` (upstream v1.2.0 merged). Never merged into the released app.
Issues: plan files in `docs/plans/`, as recorded in `AGENTS.md`.

## Problem

Two people solve Sudoku together, usually remotely. The app today is single-player: each
person opens their own copy, generates or imports their own puzzle, and narrates progress out
loud. There is no way to see the same board, share notes, or know what the other has already
done. Copying a puzzle across doesn't help either — after the first move the two boards drift
apart.

The app's state is local-only by design. `lib/main.dart` opens Hive boxes and `MyApp` shows
`HomeScreen`; every game lives in a Hive key and is loaded by `GameNotifier.build`, which
either resumes a save or generates a new puzzle. Nothing in `lib/` talks to a network and
there is no URL routing beyond `Navigator`.

## Goals

- Two players, one board, live: a digit or note entered by either appears for both within a
  moment.
- Presence and ownership: you can see where your friend's cursor is and which cells they
  filled.
- A session costs nothing and needs no account: one command on the host's Mac, one URL for
  the friend, nothing left running afterwards.
- A refresh or a server restart does not lose the board.
- The released app is untouched: no co-op code is reachable from `lib/main.dart`, the Android
  build or the release workflow.

**Non-goals:** more than two players, matchmaking, chat, hosted infrastructure, a permanent
URL, or any change to solo play.

## Actors and user stories

Two players. The host machine runs the server but has no special in-game role.

- As a player, I open the link and see whether my friend is connected.
- As a player, I start a game and my friend drops into the same board, even mid-game.
- As a player, when either of us enters a digit or a note, both boards show it.
- As a player, I can tell which cells my friend filled and which cell their cursor is on.
- As a player, I can use Undo, the hint sheet, auto-notes, the coach and export; anything
  that changes the board changes it for both of us.
- As a player, refreshing the browser puts me back on the same board with the same history.
- As the host, I run one command, share the printed URL, and close it when we stop.

## Functional scope

**F1 — Shared board.** One puzzle, one state. Both players can enter digits and notes, erase,
undo, reveal a hint, auto-fill notes, apply a coach step and start a new game. Every action
reaches both players in the same order.

**F2 — Presence and ownership.** Each player's selected cell is broadcast and drawn in the
other player's view. Cells filled by the friend use the theme's tertiary accent for the digit
text; the local player's own digits are unchanged. Notes carry no ownership marking.

**F3 — Session lifecycle.** The first player starts a game by choosing a difficulty; the other
follows. A player joining mid-game receives the puzzle and the move history and lands on the
same board. A third connection is refused. The room clock is shared, so both players and any
late joiner see the same elapsed time.

**F4 — Entry and chrome.** A separate co-op entry opens straight onto the board: a slim top
bar with connection state, the room clock and a New game control; a difficulty sheet either
player can use; a gear opening the existing settings; the existing action row, digit pad,
coach bar and export sheet. No home carousel, import library, stats or remembered difficulty.

**F5 — Resilience.** A browser refresh replays the room and rejoins. A server restart reloads
the room from disk and continues. A dropped connection retries and resyncs.

**F6 — Running a session.** One command builds and serves the co-op web app and the relay on
one origin. The friend reaches it over a `cloudflared` quick tunnel. Instructions live in the
repo. Stopping the command closes the tunnel.

**F7 — Closed by default.** The relay listens on loopback only. Every connection must carry
the session token printed in the URL and an `Origin` matching the tunnel host, because
WebSocket connections are exempt from CORS and any page could otherwise open one. Oversized
or malformed messages are dropped without touching the room. The session ends when the host
stops the tunnel.

## Implementation decisions

**Branch and entry.** Work happens on `multiplayer`. A new `lib/main_coop.dart` entry point
bootstraps the same Hive boxes as `lib/main.dart`, then shows the co-op screen instead of
`HomeScreen`. The build uses `flutter build web --target lib/main_coop.dart`, so `main.dart`,
the Android app and `fork-android.yml` are unaffected.

**Relay server.** A plain Dart process under `tool/`, using `shelf` and `shelf_web_socket`,
serving `build/web` and the WebSocket on one origin. It never interprets game rules: it orders
intents, stores them, and broadcasts. This matters because the domain cannot run on a plain
Dart VM — `Puzzle`, `GameState` helpers and `CoachStep` import `package:flutter/foundation.dart`,
so anything Flutter-free would be a second implementation of the rules.

**Ordering and conflicts.** No optimistic local echo. A player's intent goes to the server,
which assigns a monotonic sequence number and broadcasts it; every client, including the actor,
applies intents strictly in ascending order. The cost is one round trip per move; the benefit
is that divergence is structurally impossible rather than best-effort. A state hash travels
with each broadcast; a mismatch is logged rather than silently accepted.

**The sync unit is a semantic intent**, not a snapshot: digit, note, erase, undo, hint,
auto-notes, coach step, restart, start game. Each carries the parameters that change behaviour
on the actor's side, because the settings that feed them are local:

- `GameNotifier.inputDigit` decides between `GameEngine.inputDigit` and
  `GameEngine.toggleNote` from `boardProvider`'s input mode, and reads
  `settingsProvider.autoRemoveNotes`. The intent therefore records digit-versus-note and the
  resolved `autoRemoveNotes` value.
- `GameNotifier.hint` and `GameNotifier.applyCoachStep` also take `autoRemoveNotes` from
  settings. The intent carries it.
- The coach intent carries the whole applied `CoachStep`, not just its cell, so the other
  client applies exactly the eliminations the actor applied instead of recomputing.

**Undo is shared.** There is one history, so Undo removes the last action whoever made it. Both
clients apply the same `undo` intent to engines whose histories were built by the same ordered
intents, so they pop the same entry.

**Shared clock.** The room records a start timestamp; a joining client seeds the engine's
elapsed time from it, so a late joiner sees the real elapsed time rather than zero. The
existing per-second tick stays local.

**Ownership** is derived client-side by folding the applied intent log, not stored in
`GameState`: a placement sets the cell's owner, an erase or undo clears or recomputes it.
`GameState` is unchanged, so saves and exports keep working.

**Persistence.** The room (puzzle, ordered intents, start timestamp) is written as JSON after
each change to a file under `.dart_tool/`, which is already ignored, and reloaded at server
start. New game overwrites it.

**Security posture.** The aim is a private two-person game without a service to own, so the
guards are the cheap ones and nothing more:

- The relay binds `127.0.0.1`; `cloudflared` proxies one origin from the edge to that port, so
  no LAN listener exists and nothing else on the host is reachable.
- The URL carries a random room token. Connect rejects a wrong or missing token, and rejects
  an `Origin` that is not the tunnel host.
- Inbound messages are size-capped, decoded field by field with integers range-checked, and
  unknown fields are rejected; the stored intent log has a length cap. Room writes stay under
  `.dart_tool/coop/`.
- Static serving covers `build/web` only, with no directory listing, from a release build.
- The relay still does not validate Sudoku rules. A modified client can send a legal-shaped
  but wrong intent and corrupt both boards; that is accepted for a game between two people
  who know each other, because validating would be a second implementation of the rules.

**UI reuse.** The board, cell rendering, digit pad, action row, coach bar, settings and export
sheet are reused as they are. Presence and ownership are the only new visual states, threaded
through `SudokuCell`'s existing props rather than a parallel widget.

**Co-op controller, not a flag.** `GameNotifier.build` assumes one local writer: it loads a
Hive save, may generate a puzzle, and owns the tick timer. Co-op gets its own controller built
on `GameEngine` plus the room connection, so solo behaviour stays exactly as it is.

## Testing seams and expectations

Pure-Dart tests under `test/coop/`, no sockets and no widgets:

- **Room logic** — intents are numbered in order and replayed identically; a third connection
  is refused; a persisted room reloads with the same intents and start time; a new game clears
  the log.
- **Client controller** — an intent encodes and decodes losslessly, especially the
  digit-versus-note distinction and `autoRemoveNotes`; intents applied out of order are
  buffered until the sequence is contiguous; undo removes the same action on a second engine
  fed the same log; ownership folding matches the log.

What is not tested automatically, and is checked by hand: presence visuals, ownership accent,
connection bar, the coach bar in co-op, and the tunnel. The existing 158 tests must stay green,
which is the guard that solo play was not disturbed.

## Vertical slices

| Slice | Demo | Depends on |
|---|---|---|
| 015 — shared board end to end | Two browser windows on one board; digits, notes and erases sync; refresh rejoins; New game with a difficulty sheet | — |
| 016 — the rest of the game syncs | Undo, hint, auto-notes, coach step and restart change both boards; both clocks agree | 015 |
| 017 — presence and ownership | Friend's cursor outline and tertiary digits, connection bar, third connection refused | 015 |
| 018 — running a session | One command builds and serves; a friend joins over a `cloudflared` tunnel; docs | 015 |

016 and 017 are independent of each other. 018 depends only on the server and entry from 015.

## Out of scope

Accounts, hosted services, a stable public URL, more than two players, spectators, chat,
in-game voice, native mobile builds, merging into `main`, publishing, stats or imports in
co-op, and any change to solo play.

## Acceptance checklist

Functional:

- [ ] Two browsers on one server show the same puzzle and the same grid after each move.
- [ ] Digits, notes, erases, undo, hints, auto-notes, coach steps and restart reach both
      players, in the same order.
- [ ] A mid-game joiner lands on the current board and can undo history from before joining.
- [ ] Refreshing the browser rejoins the same board; restarting the server restores it.
- [ ] A third connection is refused.
- [ ] Both players see the same elapsed time.
- [ ] The friend's digits and cursor are visually distinct from the player's own.
- [ ] `flutter analyze`, all tests and a `--target lib/main_coop.dart` web build pass, and the
      normal web build still passes.

Security (F7):

- [ ] A connection with a wrong or missing room token is refused, and so is one whose `Origin`
      is not the tunnel host.
- [ ] An oversized or malformed message is dropped and the room keeps playing.
- [ ] While a session runs, nothing on the host listens beyond loopback.

Comfort and quality:

- [ ] A move feels immediate over the tunnel; measured round trip recorded.
- [ ] The board fits a phone browser at 360×640 and with 2× text.
- [ ] The top bar stays out of the grid's way.

## Risks and open questions

- **Round-trip latency** through a `cloudflared` quick tunnel is unknown; it will be measured
  during 015. If it feels slow, the fallback is optimistic application with a server-ordered
  correction, which is more machinery and should not be built speculatively.
- **A missed mutation** would diverge the boards; the state hash is the guard, and the
  controller wraps every mutating `GameNotifier` entry point.
- **Quick-tunnel URLs change per session** and need the host's Mac awake. Accepted.
- **WebSocket over the tunnel** must work with `wss`; verified in 018. If it does not,
  `cloudflared` is replaced, not the protocol.
- **The URL is the token holder's.** Anyone with the link can join while the tunnel lives. The
  token and `Origin` checks in F7 stop drive-by connections from other pages; they do not stop
  a person the link was forwarded to. Accepted for a private two-person game; the two-player
  cap and the session-length tunnel bound it.
- **Accent colours** for ownership are not fixed yet; they will be chosen against the existing
  themes during 017.
- **Undo attribution** (naming who made the last move in the tooltip) is undecided; it is a
  small addition if the shared undo feels surprising.
