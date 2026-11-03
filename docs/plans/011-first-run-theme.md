# 011 — First-run theme sheet

Parent: `docs/prd/home-and-settings.md`, slice 011
Depends on: 009 (the sheet points at Appearance for more themes)
Blocks: none

## Why

The palette is the one control that matters most when the app is first opened and least
afterwards. Today it is permanently on the home screen and permanently in the settings
app bar, and never appears when it would actually be useful.

## Scope

- A skippable bottom sheet shown on first launch only: six built-in swatches, the current
  selection marked, and "Keep default".
- Choosing a swatch applies it immediately; the sheet closes.
- A separate flag key in `settingsBox` records that the sheet has been shown.
- The sheet never returns, including after a restart.

## Out of scope

- A full onboarding screen, multiple steps, or a light/dark question.
- Any other first-run behaviour.

## Acceptance criteria

- [x] On a fresh install the sheet appears once, over the home screen, from a post-frame
      callback so the home has rendered first.
- [x] Picking a swatch applies it immediately and closes the sheet.
- [x] "Keep default" closes it without changing anything.
- [x] Dismissing it any other way also counts as seen, because the call site marks the
      flag when the sheet's future completes.
- [x] After a restart the sheet does not reappear; covered by a provider test against a
      real settings box.
- [x] Clearing the flag key by hand makes it appear again; no cached state beyond Hive.

## Findings (2026-11-04)

- The flag is `theme_onboarding_seen` in `settingsBox`, exposed as
  `themeOnboardingSeenProvider` in `theme_provider.dart`. It is deliberately not part of
  `AppSettings`, matching how the difficulty selection is persisted.
- `HomeScreen` became a `ConsumerStatefulWidget` only to own this one post-frame callback;
  its body is otherwise unchanged.
- Six swatches from `builtInThemes.take(6)`, each drawn as the theme's own surface with its
  primary dot inside, so light and dark options are distinguishable. The active one gets a
  thick primary border.
- All exit paths funnel through `whenComplete`, so a swipe-down or a tap outside records
  the flag without extra code.
- 153 tests pass and the web build succeeds. The sheet's appearance on a cleared site is
  the last manual check.

## Testing

Manual: clear site data on web, reload, walk the three exits, reload again. The flag's
persistence is covered by a data-layer test alongside the difficulty key.

## Notes

- Use the post-frame callback from the home screen; showing it from `main` risks a frame of
  the unthemed app first.
- Six swatches, not all eleven: the sheet is a nudge, and Appearance has the rest.
- Keep the sheet's own colours legible under both dark and light seeds.
