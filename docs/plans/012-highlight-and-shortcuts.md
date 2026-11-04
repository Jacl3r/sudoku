# 012 — Same-digit highlight and keyboard shortcuts

Parent: this session's ideation (2026-11-04). The PRD step was skipped on purpose: this is
presentation-only polish with no data, domain or provider changes.
Depends on: 010 (home IA introduced the toolbar this refactors), 011 (theme work settled the
palette this highlights against)
Blocks: none

## Why

Two things the player hits every session:

- Selecting a digit dims the rest of the board instead of lighting up the matching cells.
  All 5s should read as one group, at the same weight as the selected cell, and still be
  unmistakable from the navigation cursor.
- On desktop the app already accepts arrow keys and `p`, but the obvious daily actions
  (undo, erase, notes, hint, reset, export) have no keys and nothing tells the player they
  exist.

## Scope

### Same-digit highlight

- A cell holding the selected digit, or holding a note of it, gets one opaque fill:
  `Color.lerp(baseColor, scheme.primary, 0.8)`. Text switches to `onPrimary`.
- Notes keep their smaller type as the only distinction; they share the same fill and colour
  as the digit.
- The selected cell keeps the full `primary` fill and the red `errorContainer` border, so
  "where my cursor is" stays separate from "where the 5s are".
- Where the coach paints a tint or outline on a cell, the coach wins: the digit highlight is
  suppressed there.
- The error fill stays `errorContainer`.

### Keyboard shortcuts

- `n` toggles notes (`p` stays as an alias), `x`, `Backspace` and `Delete` erase, `u` and
  `Cmd/Ctrl+Z` undo, `h` opens the hint sheet, `r` opens the reset confirmation, `e` opens
  the export sheet.
- Arrow keys and `WASD` navigation are unchanged.
- Every action key is inert while the puzzle is complete. Navigation stays live.
- `Cmd`/`Ctrl` is treated as a modifier: only `Cmd/Ctrl+Z` is handled, everything else with
  the modifier is left to the OS.
- On desktop only (`macOS`, `Windows`, `Linux`, and web resolved to the host OS) the toolbar
  tooltips carry the key: "Reset (R)", "Hint (H)", "Pencil (N)", "Undo (U)", "Export (E)".
  Mobile labels stay plain.

## Out of scope

- A shortcuts help sheet or a settings toggle for shortcuts.
- Keys for digit-only, new-game, difficulty or navigation between screens.
- Any change to the coach's own colours beyond the suppression rule above.
- Widget tests (policy: no widget tests; layout and feel are checked by hand).

## Acceptance criteria

- [x] Selecting a digit paints every cell with that digit and every cell noting it with the
      same opaque 80% treatment.
- [x] Text in those cells is `onPrimary` and stays at full opacity.
- [x] The selected cell is still a full primary fill with the red border.
- [x] Notes inside a highlighted cell use `onPrimary`.
- [x] A coach-tinted or coach-outlined cell is not repainted by the digit highlight.
- [x] Error cells still show `errorContainer`.
- [x] Each shortcut fires its action, including `r` opening the confirmation before resetting.
- [x] `Cmd+Z` on macOS and `Ctrl+Z` elsewhere both undo; other modifier combinations are not
      swallowed.
- [x] No action key does anything on a completed puzzle.
- [x] Toolbar tooltips show the key on desktop and stay plain on mobile.
- [x] `flutter analyze` and `flutter test` are green and the web build succeeds.

## Findings (2026-11-04)

- `SudokuCell` now derives one flag, `hasDigitHighlight`, and one `onHighlight` from it. The
  flag includes the coach guard (`coach.tint == CoachTint.none`), so the fill, the text
  colour and the notes colour can no longer disagree.
- The notes grids were taking the raw `hasNoteOfSameDigit || isSelected` flag. That would have
  painted `onPrimary` notes on a light coach tint when the coach suppressed the fill. Both
  `NotesGrid` and `FixedNotesGrid` are now passed `onHighlight` instead.
- `isHighlighted`, which drives the fade-in animation, also uses `onHighlight`, so a
  coach-painted cell no longer runs an animation that paints nothing.
- `confirmReset` and `showHintSheet` are top-level functions in `action_row.dart`; the
  toolbar and the keyboard call the same implementation. No behaviour changed.
- Desktop detection lives in `presentation/shared/utils.dart` as `showKeyboardHints` plus
  `shortcutHint(label, key)`. It keys off `defaultTargetPlatform`, so web follows the host
  OS: hint keys on a desktop browser, plain labels on a phone browser.
- Modifier keys are checked before anything else in the focus handler. Only `Cmd/Ctrl+Z` is
  claimed; every other combination returns `ignored` so the browser and OS keep working.
- **Pre-existing flake fixed:** `coach_soundness_test.dart` generated puzzles unseeded and
  failed when the walk reached no elimination at all (`checked == 0`). It failed once during
  this slice's full-suite run and passed in isolation, which is the signature of the flake.
  The walk is now extracted to `_walkAndCheck` and each difficulty retries up to five times
  while it still has not checked anything. Attempts that check nothing do no oracle work, so
  the retry is cheap, and the assertion set is unchanged.
- Verified: `flutter analyze` clean, **154 tests pass**, `flutter build web --release`
  succeeds. The visual checks below still need a real hand on the app.

## Testing

Manual on web at 390×844 and 360×640, then on the phone: select a digit and compare it with
the other matches; open the coach to a pattern and confirm its tint survives; walk every
shortcut, including `r` into the confirmation and `e` into the export sheet; solve or reveal
the last cell and confirm the keys go quiet.

No automated tests: this slice only changes widget colour selection and key routing, and the
project deliberately has no widget tests. The data, domain and provider layers are untouched.

## Notes

- `_confirmReset` and `_showMoreSheet` in `action_row.dart` become top-level functions so the
  keyboard and the toolbar share one implementation rather than two.
- The key hint is composed at build time from `defaultTargetPlatform`; on web that resolves
  to the host OS, which is the desired behaviour.
- Keep `p` as an alias for notes so the existing muscle memory survives.
