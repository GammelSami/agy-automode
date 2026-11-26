# agy-automode

[Antigravity](https://antigravity.google)'s "Auto" mode is dumb. So I rebuilt [Claude Code's auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode) as an Antigravity plugin (works in terminal `agy` and [T3 Code](https://github.com/pingdotgg/t3code)).

### How the loop works

1. **Whitelist:** common commands pass immediately (without LLM).
2. **Stage 1 (~2 s):** LLM checks only your messages + the tool call → `ALLOW` or escalate.
3. **Stage 2 (~6 s):** Double-checks flagged calls (with thinking) → `ALLOW`, or deny with a reason so the agent can ask you.
4. **Human fallback:** After 3 denials in a row (or 20 total), `agy` asks you directly.

## How it compares

| Behavior | Claude Auto | `agy` built-in Auto | `agy` + `agy-automode` |
|---|---|---|---|
| Reads & workspace edits without prompts | ✅ | ✅ | ✅ |
| Judges commands from your messages | ✅ *(Sonnet 5 / server)* | ❌ *(fixed command list)* | ✅ *(Claude Sonnet or Gemini 4 Neon)* |
| Blind to agent prose & tool outputs | ✅ | ❌ *(sees full trajectory)* | ✅ |
| Two-stage check (fast → reasoned) | ✅ | ✅ | ✅ *(~2 s → ~6 s)* |
| Approves safe MCP & unknown commands | ✅ | ❌ *(prompts by default)* | ⚠️ *(yes, stays in sandbox)* |
| On denial: reason to agent instead of popup | ✅ | ❌ *(popup or turn abort)* | ✅ |
| Escalates only after 3 denials in a row / 20 total | ✅ | ❌ *(prompts immediately)* | ✅ |
| Scans tool outputs for prompt injection | ✅ | ⚠️ *(undocumented)* | ❌ |

**Safeguards:**
- **Auto mode only:** Supervised, Auto-accept edits, and Full access stay unchanged.
- **Fail-safe:** Any failure (missing `claude`/`agy`, timeout, changed `agy` logs) returns no opinion, so `agy` and T3 ask you as before.
- **Hook precedence:** A `deny` from another hook still wins over this plugin's approval.

## Install

Needs Python 3 and a signed-in [Claude Code](https://code.claude.com) CLI. No Claude subscription? Without the `claude` CLI, the classifier runs on Gemini 4 Neon through `agy` itself (or set `AUTOMODE_BACKEND=agy`).

```sh
git clone https://github.com/GammelSami/agy-automode ~/Git/agy-automode
~/Git/agy-automode/install.sh --timer
```

`install.sh` links the plugin into `~/.gemini/config/plugins` (terminal `agy`) and into every T3 Code Antigravity profile, so `git pull` updates all of them. `--timer` adds a daily systemd user timer for that pull. New agy sessions pick the plugin up; running ones don't.

For unattended use, give the classifier a long-lived Claude token (`claude setup-token`), because an interactive sign-in can expire.

## Settings

| Variable | Effect |
|---|---|
| `AUTOMODE_BACKEND` | `claude` or `agy` (Gemini), default `claude` if installed, else `agy` |
| `AUTOMODE_MODEL` | Classifier model, default `sonnet` (Claude) or `gemini-4-neon-low` (agy, see `agy models`) |
| `AUTOMODE_DISABLE=1` | Turns the plugin off |
| `AUTOMODE_SESSION_MODE=auto` | Treats every session as Auto (testing) |

Decisions are logged to `~/.local/state/agy-automode/decisions.jsonl`.

## Limits

- agy's hook input doesn't say which mode a session runs in. The plugin reads it from agy's own log (`Session <id> mode set to …` and the mode tag of the conversation's latest turn). If an agy update changes those lines, the plugin goes quiet instead of guessing.
- Approving a command doesn't take it out of agy's sandbox. A command that the sandbox blocks still fails.
- Classifying costs Claude or Antigravity usage: about one short request per command that isn't plainly read-only.
- With Gemini, each check takes ~6 s instead of ~2 s (a whole headless `agy` turn), and it shows up as a conversation in agy's history.

## Tests

```sh
python3 tests/test_automode.py          # offline
python3 tests/test_automode.py --live   # also asks the real classifier
AUTOMODE_BACKEND=agy python3 tests/test_automode.py --live   # same with Gemini
```
