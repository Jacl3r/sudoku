# 008 — Import library

Parent: `docs/prd/home-and-settings.md`, slice 008
Depends on: 001–006 (done)
Blocks: 010

## Why

Importing currently detects a difficulty and saves the puzzle under that difficulty's
key, then jumps straight into the board. That replaces whatever game was in progress on
that difficulty, and either way the resume entry stops pointing at the older game. There
is no way to keep two imported puzzles at once.

## Scope

- Store imports independently: `import:<id>` per puzzle plus an `__imports` index of
  `{id, savedAt}`. Difficulty keys and their format are untouched.
- `__lastPlayed` becomes a general game key — a difficulty name or `import:<id>` — so
  existing values keep working.
- `SaveGameService`: `save` gains an optional key, plus `loadKey`, `deleteKey`,
  `saveImport`, `loadImport`, `deleteImport`, and `imports()` returning newest first.
- Introduce the active save key for the running game, so `GameNotifier` loads from and
  saves back to the right place instead of always using the difficulty name. Every entry
  point sets it; the game screen clears it on dispose.
- Library screen: rows labelled by detected difficulty, date and progress; tap to open;
  `⋮` to delete; `+` to import. New imports open immediately.
- The home import icon opens the library instead of the dialog.
- The resume entry resolves imports and labels them "Imported · Hard · 12:04 · 43 of 81".
- Deleting the active import clears the marker, so the resume entry disappears.

## Out of scope

- The swipeable carousel and the Imported page (010).
- Renaming, folders, syncing or exporting the library.
- Any change to the coach or the export sheet.

## Acceptance criteria

- [x] Importing a puzzle never replaces a saved difficulty game; both remain resumable.
- [x] Two imports are kept at once and both survive a store round trip; ordering is newest
      first by last save.
- [x] Rows show difficulty, date and progress. *Ordering and data are tested; the rendered
      rows still need the manual pass.*
- [x] Tapping an import resumes that exact board; leaving the screen saves back to the
      import, not to a difficulty slot.
- [x] Deleting an import removes its row and its stored state.
- [x] Deleting the import that is the most recent game clears the resume entry.
- [x] A save without `coachEliminations` or an old difficulty-only `__lastPlayed` still
      resumes correctly.

## Findings (2026-11-04)

- `__lastPlayed` is now a plain game key. `imported_game.dart` owns the prefix helpers
  (`importKey`, `isImportKey`, `importIdFromKey`) so the data and provider layers parse it
  the same way.
- `GameNotifier` loads and saves by `activeSaveKeyProvider` rather than by difficulty. The
  lifecycle save in `game_screen.dart` uses the same key, and the index timestamp is
  refreshed on every save, so the library is ordered by last played.
- The key is **not** cleared on dispose. Riverpod throws when another provider is modified
  inside `onDispose`, and clearing is unnecessary: every entry point sets the key before
  pushing the game screen (New Game, Continue, resume, library row, import).
- `deleteKey` also prunes the import index, so finishing an imported puzzle leaves no
  dangling entry instead of a row that disappears only because its state is missing.
- 152 tests pass and the web build succeeds. Still manual: the library screen, the
  "Imported · Hard" resume label, and two imports surviving a browser reload.

## Testing

| Seam | File | Asserts |
|---|---|---|
| Import storage on a real Hive box | `test/data/services/save_game_service_test.dart` | Save/load/delete/index ordering; marker written on save and cleared when the active import is deleted |
| Marker resolution | `test/providers/resume_test.dart` | Difficulty key and `import:` key both resolve; unknown key resolves to nothing |
| Resume selection and label | `test/providers/resume_test.dart` | Most recent wins across difficulties and imports; hidden when complete; import label |

## Notes

- The active-key change is the risky part: `GameNotifier` currently derives everything from
  `difficultyProvider`. The key must be set before the game screen is pushed and cleared
  when it pops, or a later New Game will save into the previous import.
- `__imports` is a single key holding a JSON list. Keep it small: id and `savedAt` only;
  difficulty and progress come from the stored `GameState`.
- Imported difficulty is a label. Do not write it to `difficultyProvider` for the library
  list, only when resuming an import so the game screen's fallback is sensible.
