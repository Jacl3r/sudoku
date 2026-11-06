# 018 — Run a session

Parent: `docs/prd/multiplayer.md`, slice 018
Depends on: 015
Blocks: none

## Why

After 015 the co-op mode works locally, but starting a real session still means remembering a
build target, a serve command and a tunnel command. If it isn't one command plus a pasted link,
it won't get used on the evenings you actually want to play.

## Scope

- One script that builds the co-op web target and starts the relay, then prints the local URL
  and the tunnel command to run next to it. No arguments for the normal case. The printed URL
  carries the room token from PRD F7, because that token is the only thing standing between a
  stranger and the board.
- A short `docs/coop.md` aimed at the two of you: install `cloudflared` once with Homebrew,
  start the script, run the quick tunnel, paste the URL to the friend, close both when done.
  Say plainly that the link is the password, so share it privately and stop the tunnel after.
- Confirm the app connects over the tunnel with `wss` and that a move round trip is acceptable;
  record the measured round trip in the doc.
- State clearly where the room file lives, that it is safe to delete, and that starting a new
  game overwrites it.

## Out of scope

- A permanent URL, a custom domain, a Cloudflare account, or any deploy.
- Auto-starting the tunnel, or a one-command session that includes it if that needs an account.
- Packaging the server for distribution.

## Acceptance criteria

- [ ] From a clean checkout on the Mac, one command produces a served co-op app.
- [ ] The friend joins over a `cloudflared` quick tunnel and plays a full move cycle.
- [ ] WebSocket traffic works over the tunnel; if it does not, the alternative is documented
      and the protocol unchanged.
- [ ] A measured move round trip is recorded in `docs/coop.md`.
- [ ] The doc explains stopping the session and what deleting the room file does.
- [ ] Stopping the command ends the session, and nothing on the host is left listening.
- [ ] Nothing runtime-generated is tracked by git.

## Testing

Manual end to end with both players. No automated test for the script; the underlying room and
controller behaviour is covered by 015 and 016.

## Notes

- Quick-tunnel URLs change every run and stop working when the process ends. That is accepted;
  a stable URL would need a Cloudflare account, which was ruled out.
- The host's Mac must stay awake while playing. Mention it in the doc rather than working
  around it.
- Measure the round trip through the tunnel, not on loopback; loopback numbers would flatter
  the result and hide the one number that decides whether the no-echo design feels right.
