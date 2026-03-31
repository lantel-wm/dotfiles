if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ -r "$HOME/.config/zsh/login.local.zsh" ]; then
  . "$HOME/.config/zsh/login.local.zsh"
fi
