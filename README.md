# Termux + GitHub Copilot CLI + Neovim

A setup for running [GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/use-copilot-agents/use-copilot-cli)
natively on Android in Termux, so you can see the files Copilot changes the way you
would in VS Code: a file tree, change markers, side-by-side diffs and live reload.

There are two ways to view changes:

| | Neovim + tmux (`cdev`) | code-server (`vscode`) |
|---|---|---|
| Runs in | Termux | Your phone's browser |
| Weight | Light | Heavier (Node server) |
| Diff view | diffview.nvim, gitsigns | Real VS Code Source Control |
| Live reload | Yes (about 1s) | Yes |

## Install

```bash
pkg install -y git
git clone https://github.com/abhishek-raj/termux-copilot-neovim.git ~/p/termux-copilot-neovim
cd ~/p/termux-copilot-neovim
bash install.sh
```

The installer shows a menu. Pick parts by number (for example `1 2 4`), press Enter for the
recommended set, or type `a` for everything. Parts already set up are marked `[installed]`.

| # | Part | What it does |
|---|---|---|
| 1 | `copilot` | Installs Copilot CLI and makes it run in native Termux (see Step 1) |
| 2 | `scroll` | Runs `copilot` inside tmux so swipe-scrolling works |
| 3 | `keyboard` | Adds a ⌨ button to the extra-keys bar to open the keyboard |
| 4 | `neovim` | Neovim config + `cdev` workspace for watching Copilot's changes live |
| 5 | `vscode` | code-server (VS Code in the browser) with `vscode` / `vscode-stop` |
| 6 | `creds` | Encrypted GitHub login for git (asks you to choose a passphrase) |
| 7 | `gh` | GitHub CLI using that encrypted login (adds `creds` if needed) |

Recommended (Enter): `copilot scroll keyboard neovim`. Without the menu:
`bash install.sh copilot scroll`, `bash install.sh all`, or `bash install.sh --help`.
If a part fails, the others still run, and the installer prints the command to retry it.
Then run `source ~/.bashrc` and start `copilot` (`/login` on first run).

Neovim 0.12 or newer is required, because the config uses the built-in `vim.pack` plugin manager.
An ARM64 (aarch64) phone is required for Copilot CLI.

The installer is safe to re-run. Any file it replaces is backed up as `*.bak-<timestamp>`.

## Step 1: getting Copilot CLI to run in native Termux

`bash install.sh copilot` does this automatically. The details are here for troubleshooting.
This was confirmed working with Copilot CLI **1.0.105**; it's a workaround, not
official Termux support.

**Why plain `npm install -g @github/copilot` fails.** Scripts such as
[NilsSei/copilot-termux-setup](https://github.com/NilsSei/copilot-termux-setup)
weren't enough on their own, for these reasons:

1. Termux's Node reports the platform as `android arm64`. Copilot has no Android
   package, only `@github/copilot-linux-arm64`, so npm doesn't install it.
2. Installing that package isn't enough either. It's a glibc binary that needs
   `/lib/ld-linux-aarch64.so.1`, which exists in proot/Ubuntu but not in native Termux.
3. Copilot's npm loader hides the real launch error and reports
   `no platform package found`, even when the package is present.

**The fix** (`scripts/fix-copilot-launcher.sh`):

```bash
pkg install glibc-repo && pkg install glibc-runner   # Termux glibc at $PREFIX/glibc
npm install -g @github/copilot --ignore-scripts
bash scripts/fix-copilot-launcher.sh
```

The script:
- installs `@github/copilot-linux-arm64` matching the installed Copilot version
  (`--os=linux --cpu=arm64 --libc=glibc`, with package scripts disabled);
- replaces `$PREFIX/bin/copilot` with a launcher that runs the binary through
  Termux's glibc loader:
  ```bash
  "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" --library-path "$PREFIX/glibc/lib" \
    "$PREFIX/lib/node_modules/@github/copilot/node_modules/@github/copilot-linux-arm64/copilot" "$@"
  ```
  The launcher also sets the Termux CA certificate variables, adds `$PREFIX/glibc/bin`
  to `PATH`, and unsets `LD_PRELOAD`;
- checks that `copilot --version` and `--help` work before swapping the launcher in,
  and backs up the old one as `$PREFIX/bin/copilot.before-termux-copilot-fix.*`.

**After `copilot update` or reinstalling with npm**, run
`bash scripts/fix-copilot-launcher.sh` again, because the launcher or required
version may have changed. To undo, `cp -p <backup> $PREFIX/bin/copilot`.

No proot or Ubuntu installation is needed once this is applied.

## What gets installed

| File | Purpose |
|---|---|
| `scripts/fix-copilot-launcher.sh` → `$PREFIX/bin/copilot` | glibc launcher for Copilot CLI (Step 1) |
| `config/nvim/init.lua` → `~/.config/nvim/init.lua` | Neovim config that looks and works like VS Code |
| `config/tmux.conf` → `~/.tmux.conf` | Mouse/touch on, focus events, tab-style status bar |
| `bin/cdev` → `$PREFIX/bin/cdev` | Opens Copilot, Neovim and a shell as tmux tabs |
| `bin/vscode` → `$PREFIX/bin/vscode` | Starts code-server and opens it in the browser |
| `bin/vscode-stop` → `$PREFIX/bin/vscode-stop` | Stops the code-server started by `vscode` |
| `bin/git-credential-manager-termux` → `$PREFIX/bin/` | Runs Git Credential Manager on Termux's .NET (see GitHub credentials) |
| `config/bashrc.d/copilot-tmux.sh` → appended to `~/.bashrc` | `copilot` wrapper that always runs inside tmux |
| `config/bashrc.d/gh.sh` → appended to `~/.bashrc` | `gh` wrapper that uses the encrypted login (see GitHub credentials) |
| `config/termux.properties` → appended to `~/.termux/termux.properties` | ⌨ keyboard toggle button |
| `config/code-server/settings.json` | VS Code settings: auto-save, inline diffs on small screens |

Packages, by part: `copilot` → `nodejs` (if missing) `glibc-repo glibc-runner`;
`scroll` → `tmux`; `neovim` → `neovim tmux lazygit ripgrep fd git termux-api`;
`vscode` → `tur-repo code-server`; `creds` → `git-credential-manager pass gnupg`; `gh` → `gh`.

## Usage

```bash
cd myproject
git init && git add -A && git commit -m init   # diffs need a git repo with a first commit
cdev                                           # tabs: 1 copilot | 2 editor | 3 shell
cdev --split                                   # Neovim on top, Copilot below
vscode                                         # VS Code in the browser; prints the password
vscode-stop                                    # stop it again
```

Switch tmux tabs by tapping them in the status bar or pressing **Alt+1/2/3**.
**Alt+z** zooms the current pane.

### Neovim keys (leader = Space; press Space and wait for a menu)

| Keys | Action |
|---|---|
| `Space e` | File explorer |
| `Space gs` | Changed files, like VS Code's Source Control |
| `Space gd` | Side-by-side diff of all changes (`Space gq` closes it) |
| `Space gh` | History of the current file |
| `Space gg` | lazygit |
| `]c` / `[c` | Next / previous change |
| `Space hp` | Preview a change inline |
| `Space hr` / `Space hR` | Revert one change / the whole file |
| `Space hs` | Stage (accept) a change |
| `Space ff` / `Space fg` | Find a file / search text |
| `Tab` / `Shift+Tab` | Next / previous buffer tab |
| `Space u` | Update plugins |

Files that Copilot edits reload automatically and show a "Reloaded" message.

## Termux quirks this setup works around

1. **Can't scroll Copilot's output.** Copilot CLI turns on mouse mode 1003
   (any-event), which Termux ignores, so swipes are sent as arrow keys. The
   `copilot` wrapper in `~/.bashrc` runs it inside tmux, which handles that mode.
   This fixes scrolling and also makes taps work (tabs, sessions and so on).
   Use `command copilot` to bypass the wrapper.
2. **Tapping no longer opens the keyboard.** Termux doesn't show the keyboard on
   tap while an app is using the mouse. Use the **⌨** button in the extra-keys
   bar, or swipe in from the left edge and tap **KEYBOARD**.
3. **Output disappears after exiting.** tmux clears its screen when it closes. Use
   `/exit print` in Copilot to print the session to the terminal.
4. **`basename: error while loading shared libraries: .../glibc/lib/libm.so: invalid ELF header`.**
   This sometimes appears in output from commands Copilot runs. It comes from the
   glibc coreutils that the launcher puts on `PATH`, and is usually harmless. If a
   command actually fails because of it, call the Termux version directly, e.g.
   `$PREFIX/bin/basename`.
5. **`copilot` says `no platform package found`.** Run `bash scripts/fix-copilot-launcher.sh`
   again (see Step 1). If it reports a missing shared library, reinstall `glibc-runner`.

## code-server notes

- It listens on `127.0.0.1:8080` only. The password is in `~/.config/code-server/config.yaml`.
- GitHub Copilot comes built into code-server (confirmed with 4.144), so nothing
  needs installing. Click the Copilot/Accounts icon and sign in with GitHub to get
  chat and inline suggestions, as in desktop VS Code. You can still use the Copilot
  CLI alongside it.
- To stop it, run `vscode-stop`. It uses the process number `vscode` saved in `~/.cache/code-server.pid`, and finds the running code-server if that file is missing.

## GitHub credentials (encrypted, no plain-text token)

`scripts/setup-git-credentials.sh` sets up [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager)
so that git signs in to GitHub through the browser and stores the login **encrypted with GPG** (in `pass`'s store,
`~/.password-store`), instead of a plain-text token in `~/.git-credentials`.

`bash install.sh creds` runs it (it asks for your GitHub username). Run it in a normal Termux tab,
because it asks you to choose a GPG passphrase. To run it directly:

```bash
GITHUB_USER=<your-github-login> bash scripts/setup-git-credentials.sh
```

On your first `git push`, it shows a code to enter at https://github.com/login/device.
**Check which GitHub account the browser is signed in to before approving**, especially if you
use one account for Copilot and another for your repos.

- **Termux workaround:** Termux's `git-credential-manager` 3.0.2 asks for .NET 10.0.14, but
  Termux only ships 10.0.13, so it won't start. `bin/git-credential-manager-termux` runs it on
  the installed .NET instead, and git is set to `credential.helper manager-termux`.
- **Settings it applies (global git config):** `credentialStore gpg`, `gpgPath $PREFIX/bin/gpg`,
  `gitHubAuthModes device`, and `credential.https://github.com.username` (if `GITHUB_USER` is set).
  It also adds `export GPG_TTY=$(tty)` to `~/.bashrc`, so gpg can ask for the passphrase.
- **GitHub CLI (`gh`):** `gh auth login` would store its token in plain text on Termux, because
  there's no keyring for it. Instead, a `gh()` function in `~/.bashrc` (from `config/bashrc.d/gh.sh`)
  borrows the encrypted login from Git Credential Manager each time it runs, so you don't run
  `gh auth login` at all. That login has the `repo`, `gist` and `workflow` permissions, so
  `gh repo create` works; organization commands that need `read:org` may not. Install with
  `bash install.sh gh`.
- **If you forget the GPG passphrase:** the stored logins can't be recovered. Delete
  `~/.password-store` and the key (`gpg --delete-secret-and-public-key <id>`), run the script
  again, and sign in again. Your GitHub account and repos aren't affected.

## Uninstall

```bash
vscode-stop; rm -f $PREFIX/bin/cdev $PREFIX/bin/vscode $PREFIX/bin/vscode-stop
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.tmux.conf
# Then remove the copilot() and gh() blocks from ~/.bashrc and the extra-keys lines from
# ~/.termux/termux.properties (or restore the *.bak-* files).
```
