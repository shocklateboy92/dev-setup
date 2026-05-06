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
# Reuses the npm-global PATH already configured by install-todoist-cli.sh
# and exported via shell/env.sh.

ensure_system_package node nodejs nodejs nodejs
ensure_system_package npm npm npm node

if has_command kagi; then
  log_info "upgrading kagi-cli"
else
  log_info "installing kagi-cli"
fi
npm install -g --silent kagi-cli >/dev/null

# Resolve the binary even if the npm prefix isn't on PATH yet in this shell.
kagi_bin="$(command -v kagi || true)"
if [[ -z "$kagi_bin" && -x "$HOME/.npm-global/bin/kagi" ]]; then
  kagi_bin="$HOME/.npm-global/bin/kagi"
fi

if [[ -z "$kagi_bin" ]]; then
  log_error "kagi CLI installed but not found on PATH"
  return 1
fi

log_info "kagi CLI: $("$kagi_bin" --version 2>/dev/null || echo 'installed')"
