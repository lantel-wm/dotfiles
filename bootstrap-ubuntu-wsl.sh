#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script targets Ubuntu / Debian / WSL" >&2
  exit 1
fi

required_packages=(
  git
  stow
  zsh
  curl
  wget
  fzf
  zoxide
  ripgrep
  jq
  fd-find
  bat
)

optional_packages=(
  eza
  helix
  zellij
  yazi
  lazygit
  wslu
)

echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y "${required_packages[@]}"

available_optional=()
for pkg in "${optional_packages[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    available_optional+=("$pkg")
  fi
done

if ((${#available_optional[@]} > 0)); then
  echo "Installing optional packages: ${available_optional[*]}"
  sudo apt-get install -y "${available_optional[@]}"
fi

mkdir -p "$HOME/.local/bin"

if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

cat <<'EOF'

Bootstrap complete.

Recommended next steps:
  1. git clone <your-dotfiles-repo> ~/dotfiles
  2. cd ~/dotfiles
  3. ./dry-run.sh
  4. ./backup-and-stow.sh

If you want zsh as the default shell:
  chsh -s "$(command -v zsh)"

If this is WSL and you want browser integration:
  use wslview when available
EOF
