# agy-automode

Claude-style auto mode for [Antigravity](https://antigravity.google) (`agy`), including its sessions in [T3 Code](https://github.com/pingdotgg/t3code).

agy's own Auto mode asks about every command it doesn't know, so in T3 Code's **Auto** you approve `ssh`, pipes and the like over and over. This plugin puts a transcript classifier in front of those prompts, built like [Claude Code's auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode):

- It only acts while the agy session runs in Auto. Supervised, Auto-accept edits and Full access stay unchanged.
- Safe tools (reads, search, task list, T3's own MCP tools) and edits inside the workspace pass untouched, as do simple read-only commands such as `git status` or `ls`.
- Everything else goes to Claude (`claude -p`, Sonnet by default). The classifier sees **only your messages and the agent's tool calls**, never tool output or the agent's own text, so neither a file's content nor the agent can talk it into anything.
- A fast one-word check approves most actions in about 2 s. Only a BLOCK gets a second, reasoned pass.
- A block reaches the agent as "automatic check, not the user", with the reason. The agent then tells you what it wants to run. Reply "yes, you may run …" and the next attempt is allowed.
- After 3 blocks in a row, or 20 in a conversation, you decide instead (`force_ask`).
- Any failure (no `claude`, timeout, an agy update that changes its logs) means no opinion: agy and T3 ask you as before. The plugin never approves anything on its own.
- Other hooks keep priority: a `deny` from another hook still wins over this plugin's approval.

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
