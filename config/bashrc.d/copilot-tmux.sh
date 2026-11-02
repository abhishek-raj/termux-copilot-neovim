# Termux ignores mouse mode 1003 that Copilot CLI uses, so swipe-scrolling breaks.
# Running it inside tmux translates mouse events so scrolling works.
copilot() {
  if [ -z "$TMUX" ] && [ -t 1 ]; then
    tmux new-session -s "copilot-$$-$RANDOM" -c "$PWD" -- "$PREFIX/bin/copilot" "$@"
  else
    command copilot "$@"
  fi
}
