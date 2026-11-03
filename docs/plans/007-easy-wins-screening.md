# 007 — Easy-wins screening

Parent: `docs/prd/coach-and-export.md`, slice 6
Depends on: 001–006
Blocks: none

## Why

Once the coach, export and resume work are in, the app deserves one deliberate pass
for cheap, high-value fixes that were noticed along the way but never judged. The
risk is the opposite of scope creep: a list of "improvements" that quietly makes the
app heavier. The clean, lite feel is the priority, so each item has to justify its
weight, not just its correctness.

## Scope

- Screen the app for small, concrete issues: rough edges in the existing flows,
  dead code left by the coach work, inconsistent copy, obvious accessibility gaps,
  and anything the coach or export work exposed.
- Deliver a prioritised list, not code. Each item states the symptom, the symbol or
  file involved, the user-visible effect, the rough effort, and what it would cost in
  visual weight or complexity.
- Recommend a top three, and explicitly list the ones that are not worth doing.
- Implement only what the owner approves, as follow-up issues.

## Out of scope

- New features.
- Restyling, new animations, new settings.
- Refactors with no user-visible effect, unless they remove something that makes the
  app harder to maintain in a way that has already caused a bug.
- Anything in the PRD's out-of-scope list.

## Acceptance criteria

- [x] Every item in the list is verified by reading the code or by reproducing it in
      the running app; nothing is listed from memory.
- [x] Each item names its user-visible effect and its cost to the lite feel.
- [x] A top three is recommended, with a one-line reason each.
- [x] Items judged not worth their weight are listed as such, with the reason.
- [x] No code changes were made before approval; the approved items are listed below.

## Testing

Not applicable: this slice produces a decision, not behaviour. The one behaviour change
with a test is the Turbot Fish fix, covered in `test/domain/engine/techniques_test.dart`.

## Findings (2026-11-04)

Screened by reading the code, then implemented after approval. Item 3 was reproduced with
a synthetic candidate board before it was fixed.

### Implemented

1. **The import sheet could start a stale puzzle.** `validPuzzle` was only set or cleared by
   the Import button, the text field had no `onChanged`, and picking a file set the text
   without clearing it. Paste B after A, press Start, and A was imported. Now any edit or
   file pick invalidates the checked puzzle, its detected difficulty and its error, and the
   button reads **Check** because that is what it does.
2. **The upstream `TurbotFish` could eliminate a candidate from a pattern cell.** It treated
   every cell as a target and skipped only the two tips. Because `solveLogically` then falls
   back to a brute force constrained by candidates, a wrong elimination could leave
   `solvedGrid` unsolved — and that result supplies the stored solution and detected
   difficulty for imports, and the difficulty rating for generated puzzles. It now skips
   all four pattern cells; a regression test pins the case where the only cells seeing both
   tips are pattern cells.
3. **Appearance had no theme swatches.** The palette was still only an app-bar icon.
   Appearance now shows the built-in swatches inline, and the settings app bar no longer
   carries `ThemeSelector`. It stays on the game screen, where a quick switch is useful.
4. **Deleting an import had no confirmation.** `⋮ → Delete` now asks first, so an hour of
   progress cannot go on a single stray tap.
5. **Copy.** The resume entry reads "Continue import · Hard" instead of "Continue Imported
   · Hard", and the Imported page's action reads "Open library".

### Withdrawn after verification

- **"Undo after finishing leaves a frozen board."** This looked real from `GameEngine.undo`
  never clearing `puzzleComplete`, but `ActionRow` already wraps every action in
  `IgnorePointer(ignoring: isFinished)`, so undo cannot be tapped on a solved board. No
  change was needed, which is exactly what this pass is for.

### Left alone

- **Resume drops undo history** (`GameState.fromJson` returns `history: const []`).
  Pre-existing, effort M, larger saves. Revisit only if it bites.
- **Dead `PuzzleImportService.sharePuzzle`** and its test: no user-visible effect, so it
  falls outside this slice's own rule.
- **Pips as controls, or save markers on them**: a feature, not a bug.
- **Board semantics for screen readers**: a genuine gap, but large, and the acceptance path
  for this app is visual.
- Anything purely cosmetic beyond items 3 and 5.

## Results

154 tests pass, `flutter analyze` is clean, and the web build succeeds.
