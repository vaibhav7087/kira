# Architecture

Kira is four mechanisms stacked, not one tool:

```
┌────────────────────────────────────────────────────────────────┐
│ 1. TOOLS (MCP)                                                 │
│    chrome-devtools MCP                                          │
│    opencode spawns npx chrome-devtools-mcp with --browserUrl    │
│    pointed at the operator Chrome's CDP debug port.             │
│    All browser control (click, read DOM, screenshot, upload)    │
│    flows through this one channel.                              │
├────────────────────────────────────────────────────────────────┤
│ 2. PERMISSIONS (opencode config)                               │
│    permission: "allow"                                          │
│    Removes per-action approval prompts so unattended runs can   │
│    act end-to-end. This is what makes scheduled autonomy real.  │
├────────────────────────────────────────────────────────────────┤
│ 3. BEHAVIOR (AGENTS.md)                                         │
│    Hard rules injected into every session: injection defense,   │
│    rate limits, quiet hours, group policy, escalation list.     │
│    This is the only thing standing between injected chat text   │
│    and a bad afternoon. Pare-read before raising limits.        │
├────────────────────────────────────────────────────────────────┤
│ 4. AUTONOMY (OS layer, nothing to do with opencode)             │
│    Windows Task Scheduler:                                      │
│    - "Kira Operator Chrome": launcher at logon                  │
│      chrome.exe --user-data-dir=<dedicated profile>             │
│           --remote-debugging-port=9223                          │
│    - "Kira Operator": powershell run-operator.ps1 every 20 min  │
│      → opportunistically probe the port → guardrails →          │
│        opencode run --auto "<prompt>" → log + lock file         │
└────────────────────────────────────────────────────────────────┘
```

## Why the dedicated Chrome profile is load-bearing

Chrome 144+ requires a per-connection consent dialog when an agent attaches
to your **default** profile, and `--remote-debugging-port` is ignored there
entirely. A dedicated `--user-data-dir` profile launched with a debugging
port needs no dialogs — which is what makes unattended runs possible without
a human clicking "Allow" every session.

Blast radius containment: service logins the agent can touch live only in
that profile. Your daily browser, its extensions, and its sessions are
invisible unless deliberately moved there.

## Data flow of one scheduled run

1. Task Scheduler invokes `run-operator.ps1` (arguments from `kira.settings.json`)
2. Guards: quiet hours → overlap lock → TCP probe of the debug port
3. `opencode run --auto "<prompt>"` runs an opencode session with full tool access
4. That session reads global `AGENTS.md` (rules) and uses the chrome-devtools MCP
5. Output lands in `last-run.txt`, timestamped decisions in `operator.log`
