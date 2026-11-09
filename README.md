# Ubuntu GNOME Desktop Setup

My Ubuntu GNOME desktop configuration backup.

## Contents

- `gnome-desktop-snapshot.sh` — backup and restore utility.
- `gnome-desktop-backup.tar.gz` — desktop configuration snapshot.

## Backup

    chmod +x gnome-desktop-snapshot.sh
    ./gnome-desktop-snapshot.sh backup

## Restore

    ./gnome-desktop-snapshot.sh restore gnome-desktop-backup.tar.gz

Review restore notes before restoring.
