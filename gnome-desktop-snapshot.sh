#!/usr/bin/env bash
# Ubuntu GNOME desktop snapshot — backup and restore
# Captures desktop preferences and software inventories without copying
# personal documents, browser profiles, credentials, or application data.

set -Eeuo pipefail

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

backup() {
  need dconf
  need tar
  need gzip

  local output="${1:-$PWD/${APP_NAME}-$(date +%Y%m%d-%H%M%S).tar.gz}"
  local work
  work="$(mktemp -d)"
  trap "rm -rf -- '$work'" EXIT

  mkdir -p "$work"/{dconf,inventory,config}

  {
    echo "Snapshot version: $VERSION"
    echo "Created: $(date --iso-8601=seconds)"
    echo "OS:"
    cat /etc/os-release 2>/dev/null || true
    echo
    echo "Kernel: $(uname -srmo)"
    echo "Desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Session: ${XDG_SESSION_TYPE:-unknown}"
    echo "GNOME Shell:"
    gnome-shell --version 2>/dev/null || true
  } > "$work/system-info.txt"

  # Desktop settings. These paths include Shell extension preferences.
  for path in /org/gnome/ /org/gtk/ /com/ubuntu/; do
    name="$(printf '%s' "$path" | tr '/' '_' | sed 's/^_*//;s/_*$//')"
    dconf dump "$path" > "$work/dconf/${name:-root}.ini" 2>/dev/null || true
  done

  gnome-extensions list --user --details \
    > "$work/inventory/gnome-extensions-user.txt" 2>&1 || true
  gnome-extensions list --enabled \
    > "$work/inventory/gnome-extensions-enabled.txt" 2>&1 || true

  if command -v apt-mark >/dev/null 2>&1; then
    apt-mark showmanual | sort > "$work/inventory/apt-manual-packages.txt"
  fi
  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='${binary:Package}\t${Version}\n' \
      > "$work/inventory/dpkg-packages.tsv" 2>/dev/null || true
  fi
  if command -v snap >/dev/null 2>&1; then
    snap list 2>/dev/null > "$work/inventory/snap-packages.txt" || true
  fi
  if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application,branch,origin \
      > "$work/inventory/flatpak-apps.tsv" 2>/dev/null || true
  fi

  # Preserve selected desktop-related user configuration only.
  for item in "${CONFIG_ROOTS[@]}"; do
    if [[ -e "$item" ]]; then
      rel="${item#"$HOME"/}"
      mkdir -p "$work/config/$(dirname "$rel")"
      cp -a "$item" "$work/config/$rel"
    fi
  done

  # Preserve installed user extensions so the snapshot can be restored offline.
  # Open Bar is intentionally excluded because the user chose to remove it.
  ext_dir="$HOME/.local/share/gnome-shell/extensions"
  if [[ -d "$ext_dir" ]]; then
    mkdir -p "$work/config/.local/share/gnome-shell/extensions"
    while IFS= read -r -d '' ext; do
      [[ "$(basename "$ext")" == "openbar@neuromorph" ]] && continue
      cp -a "$ext" "$work/config/.local/share/gnome-shell/extensions/"
    done < <(find "$ext_dir" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  # Monitor layout is useful for multi-monitor setups; it contains no credentials.
  if [[ -f "$HOME/.config/monitors.xml" ]]; then
    cp -a "$HOME/.config/monitors.xml" "$work/config/monitors.xml"
  fi

  cat > "$work/RESTORE-NOTES.txt" <<'EOF'
Review before restoring:
1. This archive contains desktop preferences and software inventories.
2. Restore imports dconf settings and copies selected desktop config assets.
3. Package and extension inventories are informational; they are not installed
   automatically.
4. Wallpaper image files are not copied. The configured wallpaper path may
   refer to a file that exists only on the original machine.
5. Do not publish this archive publicly without reviewing its contents.
EOF

  tar -czf "$output" -C "$work" .
  chmod 600 "$output"
  echo "Backup created: $output"
  echo "Size: $(du -h "$output" | cut -f1)"
  echo "Review contents with: tar -tzf \"$output\""
}

restore() {
  need dconf
  need tar

  local archive="${1:?Pass a snapshot .tar.gz file}"
  [[ -f "$archive" ]] || { echo "File not found: $archive" >&2; exit 1; }

  local work
  work="$(mktemp -d)"
  trap "rm -rf -- '$work'" EXIT
  tar -xzf "$archive" -C "$work"

  echo "This will overwrite matching GNOME/GTK/Ubuntu desktop settings"
  echo "and selected files under ~/.config and ~/.local/share."
  read -r -p "Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

  # Import only the desktop settings captured by this script.
  for file in "$work"/dconf/*.ini; do
    [[ -f "$file" ]] || continue
    case "$(basename "$file")" in
      org_gnome.ini) path="/org/gnome/" ;;
      org_gtk.ini) path="/org/gtk/" ;;
      com_ubuntu.ini) path="/com/ubuntu/" ;;
      *) continue ;;
    esac
    dconf load "$path" < "$file"
  done

  if [[ -d "$work/config" ]]; then
    mkdir -p "$HOME/.config" "$HOME/.local/share"
    cp -a "$work/config/." "$HOME/"
  fi

  echo "Desktop settings restored. Log out and back in if some changes don't appear."
  echo "Package and extension inventories are in the archive's inventory/ directory."
}

case "${1:-}" in
  backup) shift; backup "${1:-}" ;;
  restore) shift; restore "${1:-}" ;;
  -h|--help|help|"") usage ;;
  *) usage >&2; exit 2 ;;
esac
