#!/data/data/com.termux/files/usr/bin/bash
# Installs the Termux + Copilot CLI + Neovim/tmux/code-server setup.
# Safe to re-run: existing files are backed up with a .bak-<timestamp> suffix.
set -eu  # no pipefail: `yes | pkg` would fail on SIGPIPE

HERE="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d%H%M%S)"
SKIP_CODE_SERVER="${SKIP_CODE_SERVER:-0}"
SKIP_COPILOT="${SKIP_COPILOT:-0}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

backup_copy() { # src dst
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ] && ! cmp -s "$1" "$2"; then
    cp "$2" "$2.bak-$TS"
    info "Backed up $2 -> $2.bak-$TS"
  fi
  cp "$1" "$2"
}

[ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || { echo "Run this inside Termux."; exit 1; }

info "Installing packages"
yes | pkg update -y || true
command -v node >/dev/null || yes | pkg install -y nodejs || true
yes | pkg install -y git neovim tmux lazygit ripgrep fd termux-api || true

if [ "$SKIP_COPILOT" != 1 ]; then
  # Copilot CLI ships only a linux-arm64 glibc binary; run it via Termux's glibc.
  info "Copilot CLI (glibc launcher)"
  [ "$(uname -m)" = aarch64 ] || { echo "Copilot CLI setup supports aarch64 only."; exit 1; }
  yes | pkg install -y glibc-repo
  yes | pkg install -y glibc-runner
  if [ ! -f "$PREFIX/lib/node_modules/@github/copilot/package.json" ]; then
    npm install -g @github/copilot --ignore-scripts
  fi
  bash "$HERE/scripts/fix-copilot-launcher.sh"
fi
if [ "$SKIP_CODE_SERVER" != 1 ]; then
  yes | pkg install -y tur-repo
  yes | pkg install -y code-server
fi

info "Neovim config"
backup_copy "$HERE/config/nvim/init.lua" "$HOME/.config/nvim/init.lua"

info "tmux config"
backup_copy "$HERE/config/tmux.conf" "$HOME/.tmux.conf"

info "Launchers: cdev, vscode"
install -m 755 "$HERE/bin/cdev" "$PREFIX/bin/cdev"
install -m 755 "$HERE/bin/vscode" "$PREFIX/bin/vscode"

info "Copilot tmux wrapper in ~/.bashrc"
touch "$HOME/.bashrc"
if ! grep -q 'Termux ignores mouse mode 1003' "$HOME/.bashrc"; then
  { echo; cat "$HERE/config/bashrc.sh"; } >> "$HOME/.bashrc"
fi

info "Termux keyboard toggle (extra-keys)"
mkdir -p "$HOME/.termux"
PROPS="$HOME/.termux/termux.properties"
touch "$PROPS"
if grep -qE '^[[:space:]]*extra-keys[[:space:]]*=' "$PROPS"; then
  echo "    extra-keys already set in $PROPS; not overwriting."
  echo "    Add {key: KEYBOARD, display: '⌨'} to it manually if you want the button."
else
  cp "$PROPS" "$PROPS.bak-$TS"
  { echo; cat "$HERE/config/termux.properties"; } >> "$PROPS"
fi
command -v termux-reload-settings >/dev/null && termux-reload-settings || true

if [ "$SKIP_CODE_SERVER" != 1 ]; then
  info "code-server config"
  CS="$HOME/.config/code-server/config.yaml"
  mkdir -p "$(dirname "$CS")" "$HOME/.cache"
  if [ ! -f "$CS" ]; then
    printf 'bind-addr: 127.0.0.1:8080\nauth: password\npassword: %s\ncert: false\n' \
      "$(head -c 12 /dev/urandom | base64 | tr -dc a-zA-Z0-9)" > "$CS"
  fi
  chmod 600 "$CS"
  backup_copy "$HERE/config/code-server/settings.json" "$HOME/.local/share/code-server/User/settings.json"
fi

info "Installing Neovim plugins (first run takes a minute)"
nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 60000)" >/dev/null 2>&1 || true

cat <<'EOF'

Done. Restart Termux (or run: source ~/.bashrc), then:
  copilot           Copilot CLI (inside tmux so swipe-scroll works)
  cdev [dir]        Copilot + Neovim + shell as tmux tabs (--split for one screen)
  vscode [dir]      VS Code in the browser (code-server)
See README.md for keybindings.
EOF
