# shellcheck shell=bash
# Common helpers for dev-setup install scripts.
# Sourced, not executed.

log_info() { printf '\033[1;34m[dev-setup]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[1;33m[dev-setup]\033[0m %s\n' "$*" >&2; }
log_error() { printf '\033[1;31m[dev-setup]\033[0m %s\n' "$*" >&2; }

has_command() { command -v "$1" >/dev/null 2>&1; }

# Configure npm so `npm install -g` lands in a user-writable prefix without
# sudo, matching the ~/.npm-global/bin that shell/env.sh puts on PATH. Only
# reconfigures when the current prefix isn't writable (e.g. system /usr),
# otherwise leaves an already-good prefix alone. Sets NPM_GLOBAL_PREFIX to the
# resolved prefix for callers that need to locate the installed binary.
#
# Idempotent, and safe to call from every module that installs a global npm
# package -- each such module must call this itself rather than relying on
# another module having run first, so it works under any install profile.
ensure_npm_prefix() {
  NPM_GLOBAL_PREFIX="$(npm config get prefix 2>/dev/null || true)"
  if [[ -n "$NPM_GLOBAL_PREFIX" && -w "$NPM_GLOBAL_PREFIX" ]]; then
    return 0
  fi
  NPM_GLOBAL_PREFIX="$HOME/.npm-global"
  log_info "configuring npm to install global packages into $NPM_GLOBAL_PREFIX"
  mkdir -p "$NPM_GLOBAL_PREFIX"
  npm config set prefix "$NPM_GLOBAL_PREFIX"
}

is_arch() { [[ -f /etc/arch-release ]]; }
is_debian() { [[ -f /etc/debian_version ]]; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

# Install a system package using whatever package manager is available.
# Args: <command-to-check> <pacman-pkg> [apt-pkg] [brew-pkg]
ensure_system_package() {
  local check_cmd="$1" pacman_pkg="$2" apt_pkg="${3:-$2}" brew_pkg="${4:-$2}"
  if has_command "$check_cmd"; then
    return 0
  fi
  log_info "installing system package providing '$check_cmd'"
  if is_arch; then
    sudo -n pacman -S --noconfirm --needed "$pacman_pkg"
  elif is_debian; then
    sudo -n apt-get update -qq
    sudo -n apt-get install -y "$apt_pkg"
  elif is_macos && has_command brew; then
    brew install "$brew_pkg"
  else
    log_error "no supported package manager found; install '$check_cmd' manually and re-run"
    return 1
  fi
}
