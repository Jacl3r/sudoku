# 006 — Resume card and remembered difficulty

Parent: `docs/prd/coach-and-export.md`, slice 5
Depends on: 001
Blocks: none

## Why

`DifficultyProvider.build()` returns `.easy` on every cold start and nothing persists
the selection, while the Continue button in `home_screen.dart` only renders for the
selected difficulty. Someone who plays Expert therefore clicks the chevron three
times on every launch before their own game is even visible.

## Scope

- `SaveGameService` writes a meta key into `gameBox` on every save, for example
  `__lastPlayed` = `<difficulty>:<epochMillis>`.
- A provider derives the most recent resumable save: read the meta key, load that
  difficulty's state, and report nothing when the key is missing, the save is gone,
  or the save is complete.
- Home screen: a resume card above the difficulty selector showing difficulty,
  elapsed time and progress, one tap to continue into the game.
- `DifficultyProvider` persists and restores the selection under its own key in
  `settingsBox`. Do not add it to `AppSettings`.
- Leave the existing per-difficulty Continue button in place.

## Out of scope

- A list of all saved games.
- Changing how saves are keyed or stored beyond the meta key.
- Any change to `GameEngine` or the coach.

## Acceptance criteria

- [ ] After playing Expert, killing the app, and relaunching, the resume card shows
      Expert with the right elapsed time, and one tap resumes that exact board.
      *Verified at provider level; the rendered card still needs the manual pass.*
- [x] New Game starts on the difficulty last played, without touching the selector.
- [x] The card is absent when there is no save, and when the most recent save belongs
      to a completed puzzle.
- [x] Resuming restores the board, notes, elapsed time, recorded eliminations and
      assists.
- [x] Existing saves written before this change still resume. A save without
      `coachEliminations` loads with an empty ledger; a game box without the marker
      simply shows no card, and the per-difficulty Continue button still works.
- [x] `ContinueGameNotifier` ignores the meta key: the map still has one entry per
      difficulty and the existing Continue button behaves as before.

## Findings (2026-11-03)

- The marker stores only the difficulty name. The timestamp from the plan was
  dropped: nothing displays relative time and the card only needs "which", not
  "when". `delete` clears the marker when it points at that difficulty.
- Completion is detected from a full grid, not `puzzleComplete`:
  `GameState.fromJson` does not restore that flag (pre-existing), so a completed save
  read back would look unfinished.
- Tapping the card sets `difficultyProvider` first, because `GameNotifier.build`
  chooses the save to load from that provider.
- The card sits above the difficulty selector and the icon gap shrinks from 36 to 24
  when it is present, keeping the column inside a 640-tall phone without touching the
  rest of the home layout.
- `DifficultyProvider.set` persists with `unawaited`, matching the repo's
  `unawaited_futures` lint. `FakeDifficultyNotifier` now overrides `set` so tests
  never touch Hive; one existing test needed the difficulty override once the real
  provider started reading the settings box.
- 147 tests pass and the web build succeeds.

## Testing

`test/providers/`: selection logic against a fake or in-memory box — most recent wins,
missing save yields nothing, complete save yields nothing, malformed meta key is
ignored rather than throwing. The card's appearance and tap behaviour are checked
manually on web and then on the phone.

## Notes

- `ContinueGameNotifier` already maps box keys to `Difficulty` and skips unknown keys,
  which is what makes the meta-key approach safe. Keep it that way; do not switch to
  iterating all keys.
- Do not store the timestamp in `GameState`: it is domain state that is copied on
  every move, and a save-time marker is a property of the save, not the game.
