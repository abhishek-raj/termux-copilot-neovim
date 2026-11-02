#!/data/data/com.termux/files/usr/bin/bash
# Interactive installer: pick the parts of the Termux + Copilot CLI setup you want.
#   bash install.sh                 menu
#   bash install.sh copilot neovim  install by name (non-interactive)
#   bash install.sh all             everything
# Safe to re-run: replaced files are backed up as *.bak-<timestamp>.
set -eu  # no pipefail: `yes | pkg` would fail on SIGPIPE

HERE="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d%H%M%S)"
BASHRC="$HOME/.bashrc"
PROPS="$HOME/.termux/termux.properties"

IDS=(copilot scroll keyboard neovim vscode creds gh)
declare -A DESC=(
  [copilot]="Copilot CLI that runs in native Termux (glibc launcher fix)"
  [scroll]="Swipe-scrolling in Copilot CLI (runs it inside tmux)"
  [keyboard]="Keyboard toggle button in Termux's extra-keys bar"
  [neovim]="Neovim + 'cdev' workspace: see Copilot's changes live, VS Code-style"
  [vscode]="code-server: VS Code in the browser, built-in Copilot ('vscode', 'vscode-stop')"
  [creds]="Encrypted GitHub login for git (Git Credential Manager + pass); asks for a passphrase"
  [gh]="GitHub CLI 'gh', using that encrypted login (adds 'creds' if needed)"
)
RECOMMENDED="copilot scroll keyboard neovim"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

backup_copy() { # src dst
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ] && ! cmp -s "$1" "$2"; then
    cp "$2" "$2.bak-$TS"; info "Backed up $2 -> $2.bak-$TS"
  fi
  cp "$1" "$2"
}

append_block() { # snippet file -> ~/.bashrc, once (first line is the marker)
  touch "$BASHRC"
  grep -qxF "$(head -1 "$1")" "$BASHRC" || { echo; cat "$1"; } >> "$BASHRC"
}

pkgs() { yes | pkg install -y "$@" >/dev/null || { warn "pkg install $* failed"; return 1; }; }

is_installed() {
  case "$1" in
    copilot)  grep -qs 'ld-linux-aarch64' "$PREFIX/bin/copilot" ;;
    scroll)   grep -qsxF "$(head -1 "$HERE/config/bashrc.d/copilot-tmux.sh")" "$BASHRC" ;;
    keyboard) grep -qs 'key: KEYBOARD' "$PROPS" ;;
    neovim)   [ -x "$PREFIX/bin/cdev" ] && cmp -s "$HERE/config/nvim/init.lua" "$HOME/.config/nvim/init.lua" ;;
    vscode)   command -v code-server >/dev/null && [ -x "$PREFIX/bin/vscode-stop" ] ;;
    creds)    [ "$(git config --global credential.helper 2>/dev/null)" = manager-termux ] && [ -f "$HOME/.password-store/.gpg-id" ] ;;
    gh)       command -v gh >/dev/null && grep -qsxF "$(head -1 "$HERE/config/bashrc.d/gh.sh")" "$BASHRC" ;;
  esac
}

# ---------------------------------------------------------------- components
tmux_conf_done=0
setup_tmux() {
  [ "$tmux_conf_done" = 1 ] && return
  pkgs tmux; backup_copy "$HERE/config/tmux.conf" "$HOME/.tmux.conf"; tmux_conf_done=1
}

do_copilot() {
  [ "$(uname -m)" = aarch64 ] || { warn "Copilot CLI fix supports aarch64 only; skipping."; return; }
  command -v node >/dev/null || pkgs nodejs
  pkgs glibc-repo && pkgs glibc-runner
  [ -f "$PREFIX/lib/node_modules/@github/copilot/package.json" ] || npm install -g @github/copilot --ignore-scripts
  bash "$HERE/scripts/fix-copilot-launcher.sh"
}

do_scroll() {
  setup_tmux
  append_block "$HERE/config/bashrc.d/copilot-tmux.sh"
}

do_keyboard() {
  mkdir -p "$(dirname "$PROPS")"; touch "$PROPS"
  if grep -qE '^[[:space:]]*extra-keys[[:space:]]*=' "$PROPS"; then
    warn "extra-keys is already set in $PROPS; not overwriting."
    warn "Add {key: KEYBOARD, display: '⌨'} to it yourself if you want the button."
  else
    cp "$PROPS" "$PROPS.bak-$TS"
    { echo; cat "$HERE/config/termux.properties"; } >> "$PROPS"
  fi
  command -v termux-reload-settings >/dev/null && termux-reload-settings || true
}

do_neovim() {
  pkgs neovim git lazygit ripgrep fd termux-api
  if ! nvim --headless +'lua if vim.fn.has("nvim-0.12")==0 then os.exit(1) end' +qa 2>/dev/null; then
    warn "Neovim 0.12+ is required for this config (vim.pack); run 'pkg upgrade neovim'."
  fi
  setup_tmux
  backup_copy "$HERE/config/nvim/init.lua" "$HOME/.config/nvim/init.lua"
  install -m 755 "$HERE/bin/cdev" "$PREFIX/bin/cdev"
  info "Installing Neovim plugins (first run takes a minute)"
  nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 60000)" >/dev/null 2>&1 || true
}

do_vscode() {
  pkgs tur-repo && pkgs code-server
  install -m 755 "$HERE/bin/vscode" "$HERE/bin/vscode-stop" "$PREFIX/bin/"
  local cs="$HOME/.config/code-server/config.yaml"
  mkdir -p "$(dirname "$cs")" "$HOME/.cache"
  [ -f "$cs" ] || printf 'bind-addr: 127.0.0.1:8080\nauth: password\npassword: %s\ncert: false\n' \
    "$(head -c 12 /dev/urandom | base64 | tr -dc a-zA-Z0-9)" > "$cs"
  chmod 600 "$cs"
  backup_copy "$HERE/config/code-server/settings.json" "$HOME/.local/share/code-server/User/settings.json"
}

do_creds() {
  local user="${GITHUB_USER:-}"
  if [ -z "$user" ] && [ -t 0 ]; then
    read -rp "GitHub username to sign in with (Enter to skip): " user
  fi
  GITHUB_USER="$user" bash "$HERE/scripts/setup-git-credentials.sh"
}

do_gh() {
  pkgs gh
  append_block "$HERE/config/bashrc.d/gh.sh"
  gh config set git_protocol https >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- selection
usage() {
  echo "Usage: bash install.sh [all | <part>...]"
  echo "Parts:"; for id in "${IDS[@]}"; do printf '  %-9s %s\n' "$id" "${DESC[$id]}"; done
}

menu() { # shows the menu on stderr, prints the chosen parts on stdout
  {
  echo "Termux + Copilot CLI setup. Choose what to install:"; echo
  local i=1 mark
  for id in "${IDS[@]}"; do
    mark=""; is_installed "$id" && mark=" [installed]"
    printf '  %d) %-9s %s%s\n' "$i" "$id" "${DESC[$id]}" "$mark"; i=$((i+1))
  done
  echo
  echo "Enter numbers or names separated by spaces, 'a' for all, 'q' to quit."
  } >&2
  read -rp "Selection [Enter = recommended: $RECOMMENDED]: " ans
  case "$ans" in
    q|Q) ;;
    a|A|all) echo "${IDS[*]}" ;;
    "") echo "$RECOMMENDED" ;;
    *) local out="" t
       for t in $ans; do
         if [[ "$t" =~ ^[0-9]+$ ]] && [ "$t" -ge 1 ] && [ "$t" -le "${#IDS[@]}" ]; then out+=" ${IDS[$((t-1))]}"; else out+=" $t"; fi
       done; echo "$out" ;;
  esac
}

[ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || { echo "Run this inside Termux."; exit 1; }

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  all) set -- "${IDS[@]}" ;;
  "") [ -t 0 ] || { usage; exit 1; }; set -- $(menu) ;;
esac

declare -A want=()
for p in "$@"; do
  [ -n "${DESC[$p]:-}" ] || { warn "Unknown part: $p"; usage; exit 1; }
  want[$p]=1
done
if [ -n "${want[gh]:-}" ] && [ -z "${want[creds]:-}" ] && ! is_installed creds; then
  info "'gh' needs 'creds'; adding it."; want[creds]=1
fi
[ "${#want[@]}" -gt 0 ] || { echo "Nothing selected."; exit 0; }

info "Updating package lists"
yes | pkg update -y >/dev/null 2>&1 || true

failed=""
for id in "${IDS[@]}"; do
  [ -n "${want[$id]:-}" ] || continue
  info "${id}: ${DESC[$id]}"
  set +e; ( set -e; "do_$id" ); rc=$?; set -e
  [ "$rc" = 0 ] || { warn "$id failed (exit $rc)"; failed+=" $id"; }
done
[ -z "$failed" ] || warn "Some parts failed:$failed. Fix the error above and re-run: bash install.sh$failed"

echo; echo "Done. Run 'source ~/.bashrc' (or restart Termux). Then:"
[ -n "${want[copilot]:-}${want[scroll]:-}" ] && echo "  copilot           Copilot CLI (/login on first run)"
[ -n "${want[neovim]:-}" ] && echo "  cdev [dir]        Copilot + Neovim + shell as tmux tabs (--split for one screen)"
[ -n "${want[vscode]:-}" ] && echo "  vscode [dir]      VS Code in the browser; 'vscode-stop' to stop it"
[ -n "${want[creds]:-}${want[gh]:-}" ] && echo "  gh auth status    Sign in once with the code shown (github.com/login/device)"
echo "See README.md for details."
