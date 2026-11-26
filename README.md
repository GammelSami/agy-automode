# agy-automode

[Antigravity](https://antigravity.google)'s "Auto" mode is dumb. So I rebuilt [Claude Code's auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode) as an Antigravity plugin (works in terminal `agy` and [T3 Code](https://github.com/pingdotgg/t3code)).

### How the loop works

1. **Whitelist:** common read-only commands and workspace edits pass immediately (without LLM), except reads of credential paths (`~/.ssh`, `.env`, …) and edits of agent config (`.gemini`, `AGENTS.md`, `.git`, …).
2. **Stage 1 (~3.7 s):** LLM checks only your messages + the tool call → `ALLOW` or escalate.
3. **Stage 2 (~2.5 s):** Continues the same classifier session (cached prompt) to double-check flagged calls with reasoning → `ALLOW`, or `deny` with the rule name and what you would have to say to allow it (never hangs unattended runs on interactive prompts).
4. **No duplicate `agy` prompts:** `install.sh` adds `command(*)` to `agy`'s allow list so `agy`'s built-in reversibility prompt doesn't override this classifier, while keeping the OS sandbox enabled. When `command(*)` is active, `automode.py` fails closed (`deny` on classifier error or oversized commands) and returns `force_ask` for every shell command outside Auto and Full access, so Supervised still prompts. `install.sh` only grants `command(*)` where it could link the hook.

## How it compares

| Behavior | Claude Auto | `agy` built-in Auto | `agy` + `agy-automode` |
|---|---|---|---|
| Reads & workspace edits without prompts | ✅ | ✅ | ✅ |
| Judges commands from your messages | ✅ *(Sonnet 5 / server)* | ❌ *(fixed command list)* | ✅ *(Claude Sonnet 5.5 via `agy` or `claude`)* |
| Blind to agent prose & tool outputs | ✅ | ❌ *(sees full trajectory)* | ✅ |
| Two-stage check (fast → reasoned) | ✅ | ✅ | ✅ *(~3.7 s → ~6.3 s)* |
| Approves safe MCP & unknown commands | ✅ | ❌ *(prompts by default)* | ⚠️ *(yes, stays in sandbox)* |
| On denial: reason to agent instead of popup | ✅ | ❌ *(popup or turn abort)* | ✅ |
| Non-blocking on repeated denials | ✅ | ❌ *(prompts immediately)* | ✅ |
| Scans tool outputs for prompt injection | ✅ | ⚠️ *(undocumented)* | ❌ |

**Safeguards:**
- **Auto mode only:** The classifier only runs in Auto. Full access stays unasked; with `command(*)` enabled, Supervised and Auto-accept edits get `force_ask` for every shell command (without it they stay unchanged).
- **Fail-safe:** Without `command(*)`, any failure (missing `agy`/`claude`, timeout, changed `agy` logs) returns no opinion so `agy` and T3 ask you; with `command(*)` enabled, failures and oversized commands fail closed with `deny`.
- **Hook precedence:** A `deny` from another hook still wins over this plugin's approval.

## Install

Needs Python 3 and a signed-in `agy` CLI (uses Claude Sonnet 5.5 from your Antigravity / Google AI Pro quota — no separate Claude subscription required). If you only use Antigravity through T3 Code, sign into `agy` once in a terminal first, because T3 Code stores its own Antigravity login separately. Prefer your external [Claude Code](https://code.claude.com) subscription instead? Set `AUTOMODE_BACKEND=claude`.

```sh
git clone https://github.com/GammelSami/agy-automode ~/Git/agy-automode
~/Git/agy-automode/install.sh
```

`install.sh` links the plugin into `~/.gemini/config/plugins` (terminal `agy`) and into every T3 Code Antigravity profile, so `git pull` updates all of them. `--timer` adds a daily systemd user timer for that pull: only use it if you trust every future commit here, because the pulled code runs as a hook with your rights. New agy sessions pick the plugin up; running ones don't.

When using `AUTOMODE_BACKEND=claude` unattended, give it a long-lived token (`claude setup-token`), because an interactive sign-in can expire.

## Settings

| Variable | Effect |
|---|---|
| `AUTOMODE_BACKEND` | `agy` (default if `agy` CLI is signed in) or `claude` (external Claude Code CLI) |
| `AUTOMODE_MODEL` | Classifier model, default `claude-sonnet-5-5-low` (`agy`, see `agy models`) or `sonnet` (`claude`) |
| `AUTOMODE_DISABLE=1` | Turns the plugin off |
| `AUTOMODE_SESSION_MODE=auto` | Treats every session as Auto (testing) |

Decisions are logged to `~/.local/state/agy-automode/decisions.jsonl`.

## Limits

- agy's hook input doesn't say which mode a session runs in. The plugin reads it from agy's own log (`Session <id> mode set to …` and the mode tag of the conversation's latest turn). If an agy update changes those lines, the plugin goes quiet instead of guessing (with `command(*)`: asks for every shell command).
- Approving a command doesn't take it out of agy's sandbox. A command that the sandbox blocks still fails.
- Classifying costs Antigravity or Claude usage: about one short request per command that isn't plainly read-only.
- With `agy` (default), Stage 1 + Stage 2 share one headless `stream-json` process (~3.7 s for Stage 1, ~2.5 s extra for Stage 2 with cached prompt), prompts are passed via `stdin`, and the throwaway conversation is deleted afterwards. Terminal `agy` uses `~/.gemini/antigravity-cli`, separate from T3 Code's Antigravity login.
- With `AUTOMODE_BACKEND=claude`, checks are faster (~2 s Stage 1), use the 5-minute prompt cache, and report entrypoint `agy-automode`, because plain `claude -p` (`sdk-cli`) counts about 1.8–3x against the 5-hour limit ([anthropics/claude-code#97074](https://github.com/anthropics/claude-code/issues/97074)).

## Tests

```sh
python3 tests/test_automode.py          # offline
python3 tests/test_automode.py --live   # also asks the real classifier (agy / claude-sonnet-5-5-low)
AUTOMODE_BACKEND=claude python3 tests/test_automode.py --live   # same with external Claude CLI
```
