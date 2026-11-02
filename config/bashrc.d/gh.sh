# gh: borrow the GitHub login stored encrypted by Git Credential Manager,
# so gh never writes a plain-text token (Termux has no keyring for gh).
gh() {
  if [ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] && [ ! -s "$HOME/.config/gh/hosts.yml" ]; then
    local cred tok rc
    cred="$(printf "protocol=https\nhost=github.com\n\n" | git credential fill)" || return
    tok="$(printf "%s\n" "$cred" | sed -n "s/^password=//p")"
    if [ -n "$tok" ]; then
      GH_TOKEN="$tok" command gh "$@"; rc=$?
      # Like git does after a push: save the login (encrypted) once it has worked.
      [ "$rc" -eq 0 ] && printf "%s\n\n" "$cred" | git credential approve
      return "$rc"
    fi
  fi
  command gh "$@"
}
