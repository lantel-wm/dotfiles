#!/usr/bin/env bash
set -euo pipefail

if ! command -v stow >/dev/null 2>&1; then
  echo "stow is not installed" >&2
  exit 1
fi

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

packages=(shell git conda helix nvim zellij yazi)
targets=(
  ".condarc"
  ".gitconfig"
  ".profile"
  ".zimrc"
  ".zprofile"
  ".zshenv"
  ".zshrc"
  ".config/fish/conf.d/uv.env.fish"
  ".config/git/ignore"
  ".config/helix/config.toml"
  ".config/helix/languages.toml"
  ".config/nvim/.neoconf.json"
  ".config/nvim/init.lua"
  ".config/nvim/lazy-lock.json"
  ".config/nvim/lazyvim.json"
  ".config/nvim/lua/config/autocmds.lua"
  ".config/nvim/lua/config/keymaps.lua"
  ".config/nvim/lua/config/lazy.lua"
  ".config/nvim/lua/config/options.lua"
  ".config/nvim/lua/plugins/yazi.lua"
  ".config/nvim/stylua.toml"
  ".config/yazi/init.lua"
  ".config/yazi/keymap.toml"
  ".config/yazi/package.toml"
  ".config/yazi/theme.toml"
  ".config/yazi/yazi.toml"
  ".config/zellij/config.kdl"
  ".local/bin/env"
  ".local/bin/env.fish"
  ".local/bin/zellij-session-picker"
)

case "$(uname -s)" in
  Darwin)
    packages+=(ghostty-macos)
    targets+=(".config/ghostty/config")
    ;;
esac

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
