# 010 — Home information architecture

Parent: `docs/prd/home-and-settings.md`, slice 010
Depends on: 008 (imports), 009 (the palette and About have somewhere to go)
Blocks: none

## Why

The home screen carries an About icon that duplicates Settings, a palette with no lasting
job, an import action competing with stats, and a second full-width Continue button that
now duplicates the resume entry.

## Scope

- Top bar keeps Stats and Settings. Remove About (now in Settings) and the palette (now in
  Appearance).
- Carousel becomes a `PageView` with five pages — Easy, Medium, Hard, Expert, Imported —
  keeping the chevrons and adding five dots. Swiping and tapping write the same state.
- Imported page: summary line plus "Open imported" (or "Import a puzzle" when empty).
- One primary action per page: Continue filled with New game outlined when the selected
  difficulty has a save; otherwise New game only.
- Resume entry stays an outlined button above the carousel, labelled from the resolved
  game including imports.
- Remove the separate per-difficulty Continue button.

## Out of scope

- The library screen and import flow (008).
- The first-run sheet (011).
- Any change to the game screen.

## Acceptance criteria

- [x] Home shows only Stats and Settings in the top bar.
- [x] All five pages are reachable by swipe and by chevron, and the dots reflect the page.
- [x] Swiping to a difficulty and pressing New game starts that difficulty; the page and the
      started game cannot disagree, because both read `homePageProvider`.
- [x] With a save present, Continue is filled and New game is outlined; without one, New
      game is the only action.
- [x] The Imported page shows the count and opens the library.
- [x] No duplicated Continue action remains.
- [ ] At 360×640 the column does not overflow with the resume entry, five pages, dots and
      two actions.

## Findings (2026-11-04)

- `homePageProvider` derives its state from `difficultyProvider`, so pages 0–3 cannot drift
  from the persisted difficulty. `select` also assigns the page explicitly, because
  re-selecting the current difficulty would not rebuild the provider and the Imported page
  has no difficulty to write.
- The carousel listens to the provider, so resuming a game — which writes the difficulty —
  animates the pager instead of leaving it on a stale page.
- Removed the About, Import and palette icons from the top bar. Import is now the Imported
  page's primary action, so the toolbar only has Stats and Settings.
- The logo gap dropped from 36 to 32 (20 when a resume entry is present) to pay for the
  dots and the second button. If 360×640 still overflows, the logo is the next lever, not
  the controls.
- 152 tests pass and the web build succeeds. Swipe/chevron agreement and the 360×640 fit
  are the manual checks.

## Testing

Manual on web at both viewports. The state contract — swiping writes the same selection as
the chevrons — is checked by starting a game from each page. No widget tests.

## Notes

- The page index and `difficultyProvider` must not drift. Pages 0–3 write the difficulty;
  the Imported page writes nothing, and New game is replaced by the library action there.
- Height is the likely failure: reduce the 36-pixel logo gap before touching any control.
- Keyboard navigation (`1`–`4`, existing shortcuts) still needs to agree with the page.
