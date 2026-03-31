if [ -r "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi

if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi
