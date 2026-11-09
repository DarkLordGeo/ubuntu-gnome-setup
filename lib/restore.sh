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
