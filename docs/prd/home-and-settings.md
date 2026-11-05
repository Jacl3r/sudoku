# PRD — Home, imports and settings

Status: ready for slicing
Branch: `daily-driver` (personal fork)
Work item target: `docs/plans/NNN-slug.md` (see `AGENTS.md`)

## 1. Problem

The app grew features faster than the screens that host them. From the owner's side:

1. **The home screen has controls with no lasting job.** About is an icon that duplicates
   content Settings should own; the theme palette sits on both the home screen and the
   settings app bar; import competes with stats and settings in the top bar; and there is
   no way to tell that five "difficulties" could exist rather than the four shown.
2. **Imports are second-class and destructive.** `PuzzleImportService` detects a
   difficulty and `ImportSudokuDialog` saves the new game under that difficulty's key
   before `pushReplacement`-ing straight into the board. Importing a Hard puzzle while a
   Hard game is in progress replaces that save, and either way the resume card stops
   pointing at the older game, which is then only reachable by hunting through the
   selector.
3. **Settings is a list you cannot learn from.** `GamePreview` already renders a live mini
   board, but it sits above every switch, so by the time you reach "Highlight same digits"
   the preview has scrolled away. `Default / Fidelity / Vibrant` are raw Material
   `DynamicSchemeVariant` names with no explanation, and nothing is grouped under section
   headers.
4. **The theme can only be chosen after you are already in the app.** The palette is the
   one control that matters most on first launch and least afterwards.

## 2. Goals

- One clear decision on the home screen: which game, and how to start or resume it.
- Imported puzzles as a **parallel collection** that cannot replace a saved game.
- Settings that show the effect of a control next to the control itself.
- A first-run look choice, then the palette gets out of the way.

Non-goals: renaming or organising imports into folders, sync, any change to the coach or
export behaviour, and re-testing the coach work.

## 3. Actors and user stories

Actor: the owner — a daily player who mostly plays Expert, occasionally imports a puzzle
from elsewhere, and keeps more than one game going.

- When I open the app, I see the game I was playing and one button to continue it.
- When a difficulty already has a game in progress, the emphasised action is **Continue**,
  not **New game**.
- When I import a puzzle, it joins a library of imports, it does not overwrite the game I
  was playing, and the difficulty detected for it is a label rather than a slot.
- When I want to work on a second imported puzzle, the first one is still there.
- When I change a setting, the thing it affects is directly above or below it.
- When I pick a theme, the choices show what they will look like.

## 4. Functional scope

### F1 — Home

- Top bar keeps **Stats** and **Settings** only. The About icon moves into Settings and
  opens the existing `AboutScreen`. The palette leaves the home screen and the settings
  app bar.
- The difficulty control becomes a swipeable five-page `PageView` — Easy, Medium, Hard,
  Expert, **Imported** — keeping the chevrons and adding five page dots.
- The **Imported** page summarises ("Imported · 3 puzzles") and its primary action opens
  the library; when empty the primary action is "Import a puzzle".
- One primary action per page: when the selected difficulty has a save, **Continue** is
  filled and **New game** is outlined; otherwise just **New game**. New game still
  replaces that difficulty's save, as today.
- The resume entry above the carousel is an outlined button (the same style as the
  buttons below the selector), labelled with difficulty, elapsed time and progress, and
  it surfaces imports too ("Imported · Hard · 12:04 · 43 of 81").

### F2 — Import library

- Imports are stored independently of difficulties and can never replace a saved
  difficulty game.
- Library rows are auto-labelled ("Hard · 3 Nov · 43 of 81"), tap to open, `⋮` to delete,
  `+` to paste or pick a file. A newly imported puzzle opens immediately.
- The detected difficulty is shown as a label on the row and used for nothing else.
- Imports can be resumed after an app restart and appear in the resume entry when they are
  the most recent game.
- Deleting an import that is the most recent game clears the resume entry.

### F3 — Settings

Four sections, each with a header:

- **Appearance** — theme swatches, custom colors, true black, and the scheme-variant
  control rendered as a swatch per option (primary/secondary/tertiary for that variant)
  with a one-line description of the selected one.
- **Board** — mask given cells, highlight same digits, show remaining counts, with
  `GamePreview` directly beneath them.
- **Notes** — notes layout and auto-remove notes, with a two-cell demo using the current
  layout.
- **Game** — show timer, remove animations.

Plus an **About** row that opens the existing About screen.

### F4 — First-run theme choice

- On first launch only, a skippable bottom sheet shows six built-in swatches and
  "Keep default". The choice is remembered and the sheet never returns.
- The sheet is the only place the palette appears outside Settings.

### F5 — Already applied

These came out of the manual pass and are in the working tree already; the plan should not
redo them: the resume entry switched from a filled card to an outlined button; the ink
splash and hover highlight were removed from the digit pad and action row; same-digit and
note matches use an 18% tint instead of a full primary fill, and cell highlights fade
rather than pop.

## 5. Implementation decisions

- **Import storage.** Keep using `gameBox`, with `import:<id>` for each saved import and
  `__imports` for an index of `{id, savedAt}`. The difficulty and progress come from the
  stored `GameState`; ordering comes from `savedAt`. Difficulty keys are untouched.
- **Last-played marker becomes a general key.** `__lastPlayed` holds a difficulty name or
  `import:<id>`. Existing values stay valid, so no migration is needed. Deleting the
  matched difficulty or import clears the marker, as `SaveGameService.delete` already does
  for difficulties.
- **Provider shape.** `LastPlayedNotifier` exposes the marker key rather than a
  `Difficulty`. A new imports provider watches `gameBox` for `import:*` and `__imports`
  events and exposes the library; `resumableGameProvider` resolves the marker against
  either the per-difficulty map or the library.
- **Carousel.** A page-index provider drives the `PageView`; selecting pages 0–3 still
  writes `difficultyProvider`, so `GameNotifier` keeps choosing the save to load from it.
  The Imported page writes nothing.
- **Settings structure.** Split `SettingsScreen`'s column into one widget per section with
  a shared header widget. Variant swatches come from
  `ColorScheme.fromSeed(seedColor: <active seed>, variant: v)` rendered as three dots; the
  description is a static sentence per variant.
- **Notes demo.** Two fixed cells rendered with `NotesGrid` and `FixedNotesGrid` using the
  same note set, so the layout choice is visible without a whole board.
- **First-run flag.** A separate key in `settingsBox`, not a field on `AppSettings`,
  consistent with how the difficulty selection is persisted. The sheet is shown once from
  the home screen after the first frame.
- **About.** Keep `AboutScreen` as its own route; Settings gets a row that pushes it.

## 6. Testing seams and expectations

| Seam | Where | What it proves |
|---|---|---|
| Import storage | `test/data/services/` on a real Hive box | Save, load, index ordering, delete, and the marker clearing when the active import is deleted |
| Marker resolution | `test/providers/` | A difficulty key and an `import:` key both resolve to the right game; unknown keys resolve to nothing |
| Resume selection and label | `test/providers/` | Most recent wins across difficulties and imports; hidden when the board is complete or the save is gone |
| Library ordering | `test/providers/` | Newest first by `savedAt`, stable after deletion |

No widget tests. The carousel, the section previews, the first-run sheet and the home
column's height are checked manually on web at 390×844 and 360×640, then on the phone.

## 7. Vertical slices

| # | Slice | Demo | Depends on |
|---|---|---|---|
| 008 | Import library | Import two puzzles, both survive, neither replaces a difficulty save; resume card can point at an import | 001–006 (done) |
| 009 | Settings restructure | Four sections; board preview under the board toggles; variant swatches explain themselves; About reachable | — |
| 010 | Home IA | Stats/Settings only; swipeable five-page carousel with dots; Continue emphasised when a game is running | 008, 009 |
| 011 | First-run theme sheet | Fresh install shows the sheet once; "Keep default" works; it never returns | 009 (for the "more in Settings" pointer) |

## 8. Out of scope

- Renaming imports, tags, folders, search, sync or export of the library.
- Any change to the coach, the export sheet or the game engine.
- Slices 005 (coach comfort) and 007 (easy-wins screening), which stay parked.
- Re-testing the coach work.
- Web as a shipped target; iOS and desktop.

## 9. Acceptance checklist

Functional:

- Importing a puzzle never replaces a saved difficulty game; both remain resumable.
- Two imports can be in progress at once and both survive a restart.
- The resume entry points at the most recent game, difficulty or import, with the right
  difficulty label, time and progress.
- When the selected difficulty has a save, Continue is the filled action and New game the
  outlined one.
- About is reachable from Settings and no longer from the home screen.
- Each settings toggle has its effect visible next to it; the variant control is
  understandable without prior knowledge of Material schemes.
- The first-run sheet appears once and never again.

Comfort:

- Home fits a 360×640 screen with the resume entry, five pages, dots and two actions,
  without overflow.
- Swiping between pages is smooth and does not fight the chevrons or the keyboard.
- The library is readable at a glance with several imports.

## 10. Risks and open questions

- **Home column height.** The resume entry, dots and two actions are more than the current
  layout. The fixed 36-pixel logo gap is the likely lever, not the controls.
- **Marker compatibility.** `__lastPlayed` changes meaning from "difficulty" to "game key".
  Old values must keep resolving, and `ContinueGameNotifier` must keep ignoring the key.
- **Box event volume.** Each save writes the state and the marker; the imports provider
  must filter keys rather than rebuilding on every event.
- **PageView and provider sync.** Swiping must write the same state the chevrons do,
  otherwise New Game can start on a different difficulty than the visible page.
- **First-run timing.** Showing the sheet from the first frame needs care so it does not
  flash behind the home screen or fire twice if the widget rebuilds.
