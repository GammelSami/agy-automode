# agy-automode

Claude-style auto mode for [Antigravity](https://antigravity.google) (`agy`), including its sessions in [T3 Code](https://github.com/pingdotgg/t3code).

`agy`'s built-in Auto mode prompts on almost every command outside a small fixed list (`ssh`, pipes, MCP tools). This plugin adds a transcript classifier based on the design Anthropic shared in their [Claude Code auto mode blog post](https://www.anthropic.com/engineering/claude-code-auto-mode):

1. **Fast filter (no LLM):** Reads, search, task/T3 tools, workspace edits, and simple read-only commands (`ls`, `git status`, …) pass untouched.
2. **Stage 1 (quick check, ~2 s):** Claude (`claude -p`, Sonnet by default) sees only **your messages and tool calls** — `ALLOW` runs immediately, `BLOCK` goes to stage 2.
3. **Stage 2 (reasoned check, ~6 s):** Re-evaluates blocks carefully — either `ALLOW`, or `BLOCK` back to the agent as "automatic check, not the user" so it can explain and let you reply `"yes, you may run …"`.
4. **Human fallback:** After **3 blocks in a row** or **20 in a conversation**, you decide (`force_ask`).

## How it compares

| Behavior | Claude Auto | `agy` built-in Auto | `agy` + `agy-automode` |
|---|---|---|---|
| Reads & workspace edits without prompts | ✅ | ✅ | ✅ |
| Judges commands from your messages | ✅ *(Sonnet 5 / server)* | ❌ *(fixed command list)* | ✅ *(Claude Sonnet)* |
| Blind to agent prose & tool outputs | ✅ | ❌ *(sees full trajectory)* | ✅ |
| Two-stage check (fast → reasoned) | ✅ | ✅ | ✅ *(~2 s → ~6 s)* |
| Approves safe MCP & unknown commands | ✅ | ❌ *(prompts by default)* | ⚠️ *(yes, stays in sandbox)* |
| On block: reason to agent instead of popup | ✅ | ❌ *(popup or turn abort)* | ✅ |
| Escalates only after 3 in a row / 20 total | ✅ | ❌ *(prompts immediately)* | ✅ |
| Scans tool outputs for prompt injection | ✅ | ⚠️ *(undocumented)* | ❌ |

**Safeguards:**
- **Auto mode only:** Supervised, Auto-accept edits, and Full access stay unchanged.
- **Fail-safe:** Any failure (missing `claude`, timeout, changed `agy` logs) returns no opinion, so `agy` and T3 ask you as before.
- **Hook precedence:** A `deny` from another hook still wins over this plugin's approval.

## Install

Needs Python 3 and a signed-in [Claude Code](https://code.claude.com) CLI.

```sh
git clone https://github.com/GammelSami/agy-automode ~/Git/agy-automode
~/Git/agy-automode/install.sh --timer
```

`install.sh` links the plugin into `~/.gemini/config/plugins` (terminal `agy`) and into every T3 Code Antigravity profile, so `git pull` updates all of them. `--timer` adds a daily systemd user timer for that pull. New agy sessions pick the plugin up; running ones don't.

For unattended use, give the classifier a long-lived Claude token (`claude setup-token`), because an interactive sign-in can expire.

## Settings

| Variable | Effect |
|---|---|
| `AUTOMODE_MODEL` | Classifier model, default `sonnet` |
| `AUTOMODE_DISABLE=1` | Turns the plugin off |
| `AUTOMODE_SESSION_MODE=auto` | Treats every session as Auto (testing) |

Decisions are logged to `~/.local/state/agy-automode/decisions.jsonl`.

## Limits

- agy's hook input doesn't say which mode a session runs in. The plugin reads it from agy's own log (`Session <id> mode set to …` and the mode tag of the conversation's latest turn). If an agy update changes those lines, the plugin goes quiet instead of guessing.
- Approving a command doesn't take it out of agy's sandbox. A command that the sandbox blocks still fails.
- Classifying costs Claude usage: about one short request per command that isn't plainly read-only.

## Tests

```sh
python3 tests/test_automode.py          # offline
python3 tests/test_automode.py --live   # also asks the real classifier
```
