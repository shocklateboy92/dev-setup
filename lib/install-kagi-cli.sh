# shellcheck shell=bash
# Install or upgrade the kagi CLI (https://github.com/Microck/kagi-cli).
# Sourced from install.sh.
#
# Auth: shell/env.sh exports $KAGI_SESSION_TOKEN from
# ~/.config/kagi/session-token, which install-secrets.sh materializes from
# Infisical. So this module only needs to install the binary; auth is
# already wired up by the time any agent shell starts.
#
# Strategy: ship via npm (the upstream's primary cross-platform path).
# Reuses the npm-global PATH already configured by shell/env.sh; the npm
# prefix itself is set up here via ensure_npm_prefix so this module works
# even when install-todoist-cli.sh (which also installs a global npm pkg)
# isn't part of the active profile.

ensure_system_package node nodejs nodejs nodejs
ensure_system_package npm npm npm node

# npm prefix for global installs without sudo (shared helper in common.sh;
# sets NPM_GLOBAL_PREFIX).
ensure_npm_prefix

if has_command kagi; then
  log_info "upgrading kagi-cli"
else
  log_info "installing kagi-cli"
fi
npm install -g --silent kagi-cli >/dev/null

# Resolve the binary even if the npm prefix isn't on PATH yet in this shell.
kagi_bin="$(command -v kagi || true)"
if [[ -z "$kagi_bin" && -x "$NPM_GLOBAL_PREFIX/bin/kagi" ]]; then
  kagi_bin="$NPM_GLOBAL_PREFIX/bin/kagi"
fi

if [[ -z "$kagi_bin" ]]; then
  log_error "kagi CLI installed but not found on PATH"
  return 1
fi

log_info "kagi CLI: $("$kagi_bin" --version 2>/dev/null || echo 'installed')"
