# shellcheck shell=bash
# Install or upgrade the Doist Todoist CLI (`td`) and its agent skill.
# Sourced by install.sh after lib/common.sh.
#
# Assumes shell/env.sh has already prepended ~/.npm-global/bin to PATH for
# this run (install-shell-env.sh runs first and sources it in-process).

ensure_system_package node nodejs nodejs nodejs
ensure_system_package npm npm npm node

# npm prefix for global installs without sudo (shared helper in common.sh;
# sets NPM_GLOBAL_PREFIX). shell/env.sh hardcodes ~/.npm-global on PATH for
# future shells; the helper mirrors that when the system prefix isn't writable.
ensure_npm_prefix

if has_command td; then
  log_info "upgrading @doist/todoist-cli"
else
  log_info "installing @doist/todoist-cli"
fi
npm install -g --silent @doist/todoist-cli >/dev/null

# Resolve the binary even if the npm prefix isn't on PATH yet in this shell.
td_bin="$(command -v td || true)"
if [[ -z "$td_bin" && -x "$NPM_GLOBAL_PREFIX/bin/td" ]]; then
  td_bin="$NPM_GLOBAL_PREFIX/bin/td"
fi

if [[ -z "$td_bin" ]]; then
  log_error "td CLI installed but not found on PATH"
  return 1
fi

log_info "td CLI: $("$td_bin" --version 2>/dev/null || echo 'installed')"

# Install or update the universal agent skill
# (~/.agents/skills/todoist-cli/SKILL.md). This is the Doist-maintained
# command reference; our Copilot instructions point agents at it for
# command syntax. `td skill install` errors if the file exists, so try
# update first and fall back to install on first run.
if "$td_bin" skill update universal >/dev/null 2>&1; then
  log_info "updated universal agent skill"
else
  log_info "installing universal agent skill"
  "$td_bin" skill install universal >/dev/null
fi
