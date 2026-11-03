# 009 — Settings restructure

Parent: `docs/prd/home-and-settings.md`, slice 009
Depends on: none
Blocks: 010 (the palette and About move here first)

## Why

`GamePreview` already shows a live board, but it sits above every switch, so the controls
that change it are off-screen by the time you reach them. `Default / Fidelity / Vibrant`
are raw Material scheme-variant names with no explanation, and nothing is grouped.

## Scope

- Four sections with headers: Appearance, Board, Notes, Game.
- Move `GamePreview` into Board, directly under mask-given-cells, highlight-same-digits
  and remaining-counts.
- Add a two-cell notes demo inside Notes, rendered with `NotesGrid` and `FixedNotesGrid`
  so the layout choice is visible.
- Replace the variant `SegmentedButton` with one option per variant showing three colours
  from `ColorScheme.fromSeed(seedColor: <active seed>, variant: v)` and a one-line
  description of the selected variant.
- Add an About row that pushes the existing `AboutScreen`.
- Keep theme swatches and custom colours in Appearance.

## Out of scope

- Removing the palette from the home screen or the settings app bar (010).
- New settings, new theme presets, or a redesign of `GamePreview` itself.
- The first-run sheet (011).

## Acceptance criteria

- [x] Settings shows exactly four sections — Appearance, Board, Notes, Game — plus About.
- [x] The board preview sits inside Board, after the three switches it reflects.
      *Placement is structural; the scrolling check is manual.*
- [x] The notes layout choice is visible in a demo without leaving the section.
- [x] Each variant option shows what it will look like, and the selected one has a
      plain-language description.
- [x] Every existing setting still persists and takes effect, and auto-remove-notes is now
      reachable from Notes.
- [ ] The screen fits 360×640 with the previews in place, without horizontal overflow.

## Findings (2026-11-04)

- Added an **auto-remove-notes** switch. The setting existed in `AppSettings` and was used
  by the engine, but had no control. It belongs with the notes layout rather than in Game.
- Variant rows render three dots from `ColorScheme.fromSeed` with the active seed and
  brightness, so a light theme with a bright seed shows its own colours rather than the
  page's. Labels stay Default/Fidelity/Vibrant; the description line explains the
  selection instead of the names.
- The notes demo renders **both** layouts side by side at 72 px with an 8, 9-note set, and
  outlines the selected one, so switching is visible immediately rather than after a
  reload.
- `GamePreview` moved unchanged into Board. It is the only thing on the page taller than a
  list tile, which is why the 360×640 check is still open.
- The settings app bar still hosts `ThemeSelector`; 010 removes it.
- 152 tests pass and the web build succeeds.

## Testing

Manual on web at 390×844 and 360×640: scroll each section, toggle every switch, check the
preview next to it and that the setting survives a reload. No widget tests, per
`AGENTS.md`. Persistence is already covered by the settings provider.

## Notes

- Extract a small section-header widget rather than repeating the bold label style four
  times.
- The variant description is static copy, one sentence per variant; it should say what
  changes visually, not repeat the Material term.
- The settings app bar's `ThemeSelector` stays for now; 010 removes it.
