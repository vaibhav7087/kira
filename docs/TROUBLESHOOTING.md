# Troubleshooting

Collected from a real deployment. If something's broken, it's probably here.

## "No tabs/agent can't see Chrome"
- Operator Chrome wasn't open or wasn't launched with `--remote-debugging-port`.
  Run `start-operator-chrome.cmd`.
- Port mismatch: default is 9223; make sure the browser's port in
  `kira.settings.json` matches the `--browserUrl` written by merge-config.
  (9222 is a common collision with other things running on the machine.)
- Another process is already attached: only one CDP client at a time per
  browser session is supported in chrome-devtools-mcp.

## Chrome consent dialog ("Allow remote debugging?")
Chrome 144+ requires a per-connection consent pop-up when attaching to the
**default** profile, and ignores `--remote-debugging-port` there. Kira avoids
this by design: a **dedicated profile launched with a non-default
`--user-data-dir` + the flag** is dialog-free. If you're seeing the dialog,
you're attaching to the daily Chrome — don't; use the operator profile.

## Chrome never started / starts then closes
- Chrome path wrong: set `chromePath` in `kira.settings.json` (start
  `chrome.exe --version` check isn't a thing on Windows; give full path).
- Chrome won't run as the same user twice: first run shows first-run wizard;
  the launcher already passes `--no-first-run`, so if you still see it,
  delete `chrome-profile\` and relaunch.

## MCP server never connects / npx hangs
- Node < 22 (chrome-devtools-mcp requires Node 22+): `node -v`.
- Corporate proxy blocking npm: preinstall globally
  `npm i -g chrome-devtools-mcp` then change the MCP cmd to
  `["chrome-devtools-mcp", ...]` (drop npx).

## Scheduled task runs but nothing happens
- Check `operator.log` for guards: quiet hours (23:30–08:00 by default),
  overlap lock, port probe failure.
- `run.lock` stuck: delete it (this removes the "previous run still active
  guard").
- `opencode` not on PATH *for the Task Scheduler user context* — that user
  is you, but the task might not load the same PATH. Fix in
  `run-operator.ps1`: instead of `opencode`, use the full path (e.g.
  `$env:APPDATA\npm\opencode.cmd`).

## WhatsApp attach/upload file fails
chrome-devtools-mcp's `upload_file` works only with real `<input type=file>`
elements. WhatsApp Web's attach flow (paperclip → Document) opens a native
file chooser the MCP can't drive. Workaround: click the attach element and
let the MCP click the plain exposed `input[type=file]` if one exists; if
not, skip file uploads via scheduled runs (interactive sessions with a human
can use the OS picker manually).

## Links with non-ASCII chars
Some sites return URLs with Unicode text (e.g. "→" or emoji). When you write
such a URL to a file and later read it, expect it to have been encoded as
punycode (xn--) — don't panic, nothing's broken; it round-trips.

## Logging
- `operator.log` — timestamped run decisions
- `last-run.txt` — full stdout of the last agent run
- `opencode run --auto` output goes to these only; add `-v` in the prompt
  line to opencode for tool-call logging if debugging.

## Uninstall/reinstall
`uninstall.ps1` removes tasks + scripts but keeps profile + logins; re-run
`setup-operator.ps1 -Replace` after editing `kira.settings.json` (or use
`update.ps1` after a git pull).
