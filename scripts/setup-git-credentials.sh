#!/data/data/com.termux/files/usr/bin/bash
# Git Credential Manager + GPG-encrypted store (pass) for GitHub on Termux.
# Run in a normal Termux tab: it asks you to choose a GPG passphrase.
#   GITHUB_USER=<login> bash scripts/setup-git-credentials.sh
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
export GPG_TTY="$(tty)"

yes | pkg install -y git-credential-manager pass gnupg || true
install -m 755 "$HERE/bin/git-credential-manager-termux" "$PREFIX/bin/"

git config --global credential.helper manager-termux
git config --global credential.credentialStore gpg
git config --global credential.gpgPath "$PREFIX/bin/gpg"
# Device flow: you get a code to enter at github.com/login/device (works without a desktop browser).
git config --global credential.gitHubAuthModes device
if [ -n "${GITHUB_USER:-}" ]; then
  git config --global credential.https://github.com.username "$GITHUB_USER"
fi

grep -q 'export GPG_TTY=' "$HOME/.bashrc" 2>/dev/null || \
  printf '\n# Lets gpg ask for its passphrase in the terminal (used by git credentials)\nexport GPG_TTY=$(tty)\n' >> "$HOME/.bashrc"

if [ -z "$(gpg --list-secret-keys --with-colons 2>/dev/null | grep '^sec')" ]; then
  name="$(git config --global user.name || echo termux)"
  email="$(git config --global user.email || echo termux@localhost)"
  echo "Creating a GPG key for \"$name <$email>\". Choose a passphrase and save it in your password manager."
  gpg --quick-generate-key "$name <$email>" default default never
fi
fpr="$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
[ -f "${PASSWORD_STORE_DIR:-$HOME/.password-store}/.gpg-id" ] || pass init "$fpr"

git-credential-manager-termux --version >/dev/null
echo "Done. On your first push to GitHub you'll get a code to enter at https://github.com/login/device."
