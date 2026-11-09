#!/usr/bin/env bash
# Ubuntu GNOME desktop snapshot — backup and restore
# Captures desktop preferences and software inventories without copying
# personal documents, browser profiles, credentials, or application data.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

VERSION=1
APP_NAME="gnome-desktop-snapshot"
CONFIG_ROOTS=(
  "$HOME/.config/gtk-3.0"
  "$HOME/.config/gtk-4.0"
  "$HOME/.config/autostart"
  "$HOME/.local/share/themes"
  "$HOME/.local/share/icons"
  "$HOME/.local/share/fonts"
  "$HOME/.themes"
  "$HOME/.icons"
  "$HOME/.fonts"
)

usage() {
  cat <<'EOF'
Ubuntu GNOME Desktop Snapshot

Backup:
  ./gnome-desktop-snapshot.sh backup [output.tar.gz]

Restore:
  ./gnome-desktop-snapshot.sh restore snapshot.tar.gz

The backup contains:
  - GNOME, GTK, and Ubuntu dconf settings
  - Enabled GNOME extension IDs and extension inventory
  - APT manually-installed package inventory
  - Snap and Flatpak application inventories
  - GTK settings, user themes, icons, fonts, and autostart entries
  - System/version information

Restore imports desktop settings and restores selected user config assets.
It does NOT automatically install packages or extensions.
Review the included inventories and install those separately.
EOF
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

source "$SCRIPT_DIR/lib/backup.sh"
source "$SCRIPT_DIR/lib/restore.sh"

case "${1:-}" in
  backup) shift; backup "${1:-}" ;;
  restore) shift; restore "${1:-}" ;;
  -h|--help|help|"") usage ;;
  *) usage >&2; exit 2 ;;
esac
