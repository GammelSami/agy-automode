#!/bin/sh
# Links the plugin into terminal agy (~/.gemini/config) and every T3 Code Antigravity profile,
# so `git pull` in this repo updates all of them. Re-run after adding a T3 Antigravity instance.
# --timer also installs a systemd user timer that pulls this repo daily (Linux).
set -eu
REPO=$(cd "$(dirname "$0")" && pwd)
PLUGIN="$REPO/plugins/automode"

link() {
    mkdir -p "$1"
    if [ -L "$1/automode" ] || [ ! -e "$1/automode" ]; then
        ln -sfn "$PLUGIN" "$1/automode"
        echo "linked $1/automode"
    else
        echo "skipped $1/automode: exists and is not a link (command(*) not granted there)" >&2
        return 1
    fi
}

allow_commands() {
    python3 - "$1" "$2" <<'PY'
import json, os, pathlib, sys
path, kind = pathlib.Path(sys.argv[1]), sys.argv[2]
if not path.parent.is_dir():  # never create agy's state dir (default_backend() reads its presence as a login)
    sys.exit(0)
data = json.loads(path.read_text()) if path.exists() else {}
if kind == 'settings':
    allow = data.setdefault('permissions', {}).setdefault('allow', [])
else:
    allow = data.setdefault('userSettings', {}).setdefault('globalPermissionGrants', {}).setdefault('allow', [])
if 'command(*)' not in allow:
    allow.append('command(*)')
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    tmp = path.with_suffix(path.suffix + '.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(fd, 'w') as f:
        f.write(json.dumps(data, indent=2) + '\n')
    os.replace(tmp, path)
    print(f'added command(*) to {path}')
PY
}

# command(*) only where the hook is linked: without it, nothing would gate shell commands.
if link "$HOME/.gemini/config/plugins"; then
    allow_commands "$HOME/.gemini/config/config.json" config
    allow_commands "$HOME/.gemini/antigravity-cli/settings.json" settings
fi
for profile in "$HOME"/.t3/userdata/providers/antigravity/*/; do
    [ -d "$profile" ] || continue
    link "${profile}config/plugins" || continue
    allow_commands "${profile}config/config.json" config
    allow_commands "${profile}antigravity-acp/settings.json" settings
done

[ -d "$HOME/.gemini/antigravity-cli" ] || echo "note: run 'agy' once in a terminal to sign in (or set AUTOMODE_BACKEND=claude)" >&2

if [ "${1:-}" = "--timer" ]; then
    units="$HOME/.config/systemd/user"
    mkdir -p "$units"
    cat > "$units/agy-automode-update.service" <<EOF
[Unit]
Description=Update the agy auto-mode plugin

[Service]
Type=oneshot
ExecStart=/usr/bin/git -C $REPO pull --ff-only --quiet
EOF
    cat > "$units/agy-automode-update.timer" <<EOF
[Unit]
Description=Daily update of the agy auto-mode plugin

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now agy-automode-update.timer
fi
