#!/usr/bin/env bash
set -euo pipefail

if ! command -v stow >/dev/null 2>&1; then
  echo "stow is not installed" >&2
  exit 1
fi

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
packages=(shell git conda helix nvim zellij yazi)

case "$(uname -s)" in
  Darwin)
    packages+=(ghostty-macos)
    ;;
esac

stow -d "$repo_dir" -t "$HOME" "${packages[@]}"
