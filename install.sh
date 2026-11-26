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
        echo "skipped $1/automode: exists and is not a link" >&2
    fi
}

link "$HOME/.gemini/config/plugins"
for profile in "$HOME"/.t3/userdata/providers/antigravity/*/; do
    [ -d "$profile" ] && link "${profile}config/plugins"
done

command -v claude >/dev/null || echo "note: claude CLI not found; the classifier uses Gemini through agy" >&2

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
