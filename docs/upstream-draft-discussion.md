# Draft: upstream Discussion

Status: **draft, not posted.** Posting needs the owner's explicit yes, given in the
conversation where it is posted (`docs/upstream-contribution.md`, rule 1). Attach
before/after screenshots of the Hints sheet and the Export sheet first; none exist yet.

Where: Discussions on `likhithpraveenk/sudoku`, category Ideas (or General).

Title: **Export the current board as text, for pasting into an AI chat or solver?**

Body:

> Hi Likhith, and sorry again about PR #11. That was an accident on my side, I pushed a
> branch of my personal fork and GitHub offered me the pull request button. Thanks for
> the kind reply anyway.
>
> You said an export for pasting into an AI chat would be a simple addition, so I tried a
> small version and I'd like to know if you would want it, before I send anything.
>
> What it is: an **Export puzzle** entry in the existing Hints sheet. It opens one
> bottom sheet where you pick what to export (starting puzzle, progress, or progress with
> notes), the format (one line of digits, text grid, or pencilmark grid), and whether to
> add a short prompt asking an AI for a nudge instead of the solution. One Copy button.
> Cells without notes show every digit that is still possible, so the text is a valid
> position even if the notes are partial. No new dependency, no permission, no platform
> code, and nothing about hints or the solver changes.
>
> Size: about 400 lines including tests, in three new files plus a small edit to
> `action_row.dart`. `dart format`, `dart fix` and `flutter analyze` are clean and
> `flutter test` passes.
>
> I should be upfront: I'm a UX designer, not a developer, and this was written with an
> AI coding assistant. I read through it and checked it, but you know the codebase far
> better than I do. I'm not asking you to take it. If it doesn't fit the app, or you'd
> rather keep the Hints sheet as it is, that's completely fine and I'll just keep it in
> my own fork. If you do like the idea, I'd open a small PR from a branch based on your
> current `main`, and I'm happy to change it to match how you want it.
>
> Screenshots: (attach)

Notes for whoever posts it:

- Do not link the branch in the first message; offering is enough. Link it only if he asks.
- Do not mention the coach, the redesign or the multiplayer branch. He dropped a hint
  system because it was too complex; leave that door shut unless he opens it.
- If he says no, or does not answer, stop. Do not re-ping or open a PR.
- Keep PR #11 in prose like above. Do not put a `#11` reference in any commit message.
