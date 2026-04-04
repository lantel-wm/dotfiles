#!/usr/bin/env bash
set -euo pipefail

if ! command -v stow >/dev/null 2>&1; then
  echo "stow is not installed" >&2
  exit 1
fi

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

packages=(shell git conda helix nvim zellij yazi)

case "$(uname -s)" in
  Darwin)
    packages+=(ghostty-macos)
    ;;
esac

collect_targets() {
  local package="$1"

  git -C "$repo_dir" ls-files -z -- "$package" | while IFS= read -r -d '' path; do
    printf '%s\n' "${path#"$package"/}"
  done
}

backup_target() {
  local rel="$1"
  local src="$HOME/$rel"
  local dst="$backup_root/$rel"

  [[ -e "$src" || -L "$src" ]] || return 0
  [[ -L "$src" ]] && return 0

  mkdir -p "$(dirname "$dst")"
  mv "$src" "$dst"
  echo "backed up $rel"
}

mapfile -t targets < <(
  for package in "${packages[@]}"; do
    collect_targets "$package"
  done | sort -u
)

mkdir -p "$backup_root"
for rel in "${targets[@]}"; do
  backup_target "$rel"
done

stow -R -v -d "$repo_dir" -t "$HOME" "${packages[@]}"

cat <<EOF

Backup complete.
Backup directory: $backup_root

If you need machine-local shell settings, create:
  ~/.config/zsh/local.zsh
  ~/.config/zsh/login.local.zsh
EOF
