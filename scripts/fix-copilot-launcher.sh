#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

prefix="${PREFIX:-/data/data/com.termux/files/usr}"
[[ "$prefix" == /* ]] || fail 'PREFIX must be an absolute Termux prefix.'
[[ "$(uname -m)" == aarch64 ]] || fail 'This repair supports ARM64 (aarch64) only.'

node="$prefix/bin/node"
npm_cli="$prefix/lib/node_modules/npm/bin/npm-cli.js"
package_dir="$prefix/lib/node_modules/@github/copilot"
platform_dir="$package_dir/node_modules/@github/copilot-linux-arm64"
loader="$prefix/glibc/lib/ld-linux-aarch64.so.1"
launcher="$prefix/bin/copilot"
temporary=''

trap 'if [[ -n "$temporary" ]]; then rm -f -- "$temporary"; fi' EXIT

[[ -x "$prefix/bin/bash" ]] || fail "Termux Bash is missing: $prefix/bin/bash"
[[ -x "$node" ]] || fail "Termux Node is missing: $node"
[[ -f "$npm_cli" ]] || fail "Termux npm is missing: $npm_cli"
[[ -f "$package_dir/package.json" ]] || fail 'Install the base @github/copilot package first.'
[[ -x "$loader" ]] || fail "A working Termux glibc installation is required: $loader"

version="$("$node" -p 'require(process.argv[1]).version' "$package_dir/package.json")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] \
  || fail "Invalid Copilot package version: $version"

installed_version=''
if [[ -f "$platform_dir/package.json" ]]; then
  installed_version="$("$node" -p 'require(process.argv[1]).version' "$platform_dir/package.json")"
fi

if [[ "$installed_version" != "$version" || ! -x "$platform_dir/copilot" ]]; then
  printf 'Installing @github/copilot-linux-arm64@%s...\n' "$version"
  "$node" "$npm_cli" install \
    --prefix "$package_dir" \
    --no-save --package-lock=false --ignore-scripts --no-audit --no-fund \
    --os=linux --cpu=arm64 --libc=glibc \
    "@github/copilot-linux-arm64@$version"
fi

[[ -x "$platform_dir/copilot" ]] || fail "Platform executable is missing: $platform_dir/copilot"

temporary="$(mktemp "$prefix/bin/.copilot-fix.XXXXXX")"
{
  printf '#!%s/bin/bash\n' "$prefix"
  printf 'TERMUX_PREFIX=%q\n' "$prefix"
  cat <<'LAUNCHER'
export SSL_CERT_FILE="$TERMUX_PREFIX/etc/tls/cert.pem"
export SSL_CERT_DIR="$TERMUX_PREFIX/etc/tls/certs"
export NODE_EXTRA_CA_CERTS="$TERMUX_PREFIX/etc/tls/cert.pem"
GLIBC_PREFIX="$TERMUX_PREFIX/glibc"
COPILOT="$TERMUX_PREFIX/lib/node_modules/@github/copilot/node_modules/@github/copilot-linux-arm64/copilot"
export PATH="$GLIBC_PREFIX/bin:$TERMUX_PREFIX/bin:$PATH"
unset LD_PRELOAD
exec "$GLIBC_PREFIX/lib/ld-linux-aarch64.so.1" --library-path "$GLIBC_PREFIX/lib" "$COPILOT" "$@"
LAUNCHER
} > "$temporary"
chmod 700 "$temporary"

printf 'Checking the replacement launcher before installation...\n'
"$prefix/bin/bash" -n "$temporary"
"$prefix/bin/bash" "$temporary" --version
"$prefix/bin/bash" "$temporary" --help > /dev/null

if [[ -e "$launcher" || -L "$launcher" ]]; then
  backup="$(mktemp "$launcher.before-termux-copilot-fix.XXXXXX")"
  cp -pL -- "$launcher" "$backup"
  printf 'Previous launcher backed up to: %s\n' "$backup"
fi

mv -f -- "$temporary" "$launcher"
temporary=''
printf 'Installed launcher: %s\nRun copilot in native Termux to confirm interactive startup.\n' "$launcher"
