# kira — an agentic operator for your real browser

Kira turns [OpenCode](https://opencode.ai) (or any agent that can run MCP tools and shell commands) into a **chat-reading, email-sending, web-operating operator** that works on your actual logged-in browser sessions — WhatsApp, Gmail, Instagram, Telegram, dashboards, anything you use on the web.

```
you ──► opencode (permission: allow)
          │
          ├─ chrome-devtools MCP ──► dedicated "operator" Chrome profile
          │                            └─ web.whatsapp.com / mail.google.com / instagram.com ...
          ├─ AGENTS.md hard rules ──► behavior guardrails (injection defense, rate limits, escalation)
          └─ Windows Task Scheduler ─► periodic unattended runs ("check unread chats")
```

No unofficial protocol libraries. No bots squatting in your chats. Kira uses the **official web clients** of every service, driven at human pace, so from the platform's point of view it looks exactly like you typing.

## What it does

- **Autonomous replies** on WhatsApp Web / Telegram Web / Instagram DMs / email — in your voice, under strict rules
- **On-demand operation** — "check insta", "text this person X", "email that file", "find me a flight"
- **Unattended scheduled runs** — every 20 minutes, checks unread chats and handles them per your rules
- **Survives reboots** — operator Chrome auto-starts at logon; all logins persist in its profile
- **Auditable** — every run leaves logs; every browser action goes through your real UI

## What it deliberately does NOT do

- No unofficial API bridges (whatsmeow / gramjs / BAILEY). Protocol-level automation fingerprints are how people get banned — Kira avoids that entire class of risk by driving the official web UIs.
- No auto-login in scheduled runs. If a service is logged out, the run skips it and reports the gap.
- No group replies unless you explicitly name the group.
- No sending money/OTP/password/location content — ever, even if a chat message asks for it.

## Requirements

| Need | Notes |
|---|---|
| Windows 10/11 | (scheduled tasks are schtasks/PowerShell based; macOS/Linux need adapting the service layer) |
| Chrome 144+ | remote debugging channel |
| Node.js ≥ 22 | powers chrome-devtools-mcp |
| OpenCode | installed + logged in to a model provider (`opencode`) |

## Install (clone-only, ~15 min)

```powershell
git clone https://github.com/vaibhav7087/kira.git
cd kira
.\install\setup-operator.ps1
```

The installer:
1. checks prerequisites (node, chrome, opencode on PATH)
2. writes the operator Chrome launcher + run script to `%USERPROFILE%\.opencode-operator\`
3. merges `permission: "allow"` + the `chrome-devtools` MCP server into your **global** opencode config (merge-aware: existing config is backed up and preserved)
4. appends a marked block of Kira behavior rules to your global `AGENTS.md` (only if not already present)
5. registers two scheduled tasks:
   - **Kira Operator Chrome** — launches the dialog-free operator Chrome at logon (port 9223)
   - **Kira Operator** — runs `opencode run --auto` every 20 minutes (skips when Chrome closed, quiet hours, or a run is still in progress)

Then the only manual step:

```
The installer opens the Kira Chrome window. Log into the services you want
it to operate (web.whatsapp.com QR, gmail, instagram, telegram) inside
that window. Sessions persist across reboots.
```

Smoke test:

```powershell
opencode run --auto "list my kira chrome tabs"
```

## Why a separate Chrome profile?

Chrome 144+ requires a per-connection consent dialog when an agent attaches to your **default** profile, and ignores `--remote-debugging-port` there entirely. A dedicated profile launched with a non-default `--user-data-dir` + `--remote-debugging-port` needs **no dialogs at all** — which is what makes unattended scheduled runs possible. Side effect: the agent's blast radius is a profile you keep dedicated to it, not your daily browser.

## Risk reality-check

| Platform | Ban risk with Kira | Notes |
|---|---|---|
| WhatsApp | Low | official client, human pace, 1:1 replies; Meta can't see CDP |
| Telegram | Low | official web client |
| Gmail | Low | normal web usage |
| Instagram | Low-Medium | DM velocity limits are enforced even for humans; keep the rate caps |

Risks that remain: prompt-injection steering (mitigated by hard rules, not eliminated), rate-rule erosion if you raise caps, and brittle UIs. Read `docs/PRIVACY-SECURITY.md` before going fully autonomous. **Automating personal accounts is against most platforms' ToS.** Use rate limits, prefer business-appropriate accounts, and start with approve-first mode if unsure.

## Uninstall

```powershell
.\uninstall.ps1          # removes tasks + scripts, keeps profile/logins
.\uninstall.ps1 -Purge   # also deletes the operator profile (all logins lost)
```

## FAQ

**Does this get my WhatsApp banned?** — As configured (15 msgs/hr, 40/day cap, randomized delays), you are under the threshold that trips automation detection. Ban risk is not zero; protocol bridges make it dramatically worse.

**Is my data leaving my machine?** — The only cloud involved is the LLM provider you already use. Kira's scripts and Chrome profile stay local.

**Can I use it with Claude Code / other agents?** — The template layer (launcher, rules, task scheduling) works for any agent; only the `opencode run --auto` line is OpenCode-specific in `run-operator.ps1`.

## License

MIT — see [LICENSE](LICENSE). You are responsible for how you use this.
